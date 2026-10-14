//
//  FlashJob.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import UIKit
import NordicDFU

final class FlashJob {

    var onEnd: (() -> Void)?

    private let hex: Hex
    private let target: Calliope
    private let connection: DeviceConnectionService
    private let events: (UploadEvent) -> Void
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isEnded = false

    init(hex: Hex, target: Calliope, connection: DeviceConnectionService, events: @escaping (UploadEvent) -> Void) {
        self.hex = hex
        self.target = target
        self.connection = connection
        self.events = events
    }

    // MARK: - Public API

    func start() {
        // Must happen before beginBackgroundTask, the screen has to stay on while flashing.
        UIApplication.shared.isIdleTimerDisabled = true
        LogNotify.log("🔋 Idle timer disabled - screen will stay on during flashing")

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "flashing") {
            LogNotify.log("⚠️ Background task expiring - the app must stay in the foreground while flashing")
        }

        // A device still running the Blocks/Campus runtime needs a full DFU, and only a live GATT probe can tell.
        if let flashable = target as? FlashableBLECalliope {
            flashable.prepareFlashMode { [weak self] in
                self?.startUpload()
            }
        } else {
            startUpload()
        }
    }

    func cancel() {
        guard !isEnded else { return }
        _ = target.cancelUpload()
        end()
        // The picked USB volume may be unusable after an interrupted copy.
        if target is USBCalliope {
            connection.resetUsbConnectionAfterCopy()
        }
        emit(.cancelled)
    }

    func connectionLost() {
        fail(.connectionLost)
    }

    // Replaced by a newer upload: stop quietly, the new upload owns the UI.
    func abandon() {
        guard !isEnded else { return }
        _ = target.cancelUpload()
        end(resetDfuMode: false)
    }

    // MARK: - Private Helpers

    private func startUpload() {
        guard !isEnded else { return }
        connection.setDfuMode(true)
        emit(.progress(target is USBCalliope ? nil : 0))

        if let usb = target as? USBCalliope {
            // Must not capture self: the target would otherwise retain this job.
            usb.onTransferRejected = { [events] reason in
                DispatchQueue.main.async {
                    events(.failed(.transferRejected(reason)))
                }
            }
        }

        if let flashable = target as? FlashableBLECalliope {
            // Must not capture self: the target would otherwise retain this job.
            flashable.requestDisconnectCallback = { [connection] in
                LogNotify.log("[PartialFlash] Disconnect requested - triggering immediate disconnect")
                connection.disconnectForReboot()
            }
        }

        do {
            try target.upload(file: hex, progressReceiver: self, statusDelegate: self, logReceiver: self)
        } catch {
            fail(.dfu(error.localizedDescription))
        }
    }

    private func complete() {
        guard !isEnded else { return }
        end()
        emit(.completed)
    }

    private func fail(_ error: UploadError) {
        guard !isEnded else { return }
        LogNotify.error("Upload failed: \(error)")
        end()
        emit(.failed(error))
    }

    private func end(resetDfuMode: Bool = true) {
        isEnded = true
        UIApplication.shared.isIdleTimerDisabled = false
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        if resetDfuMode {
            connection.setDfuMode(false)
        }
        onEnd?()
    }

    private func emit(_ event: UploadEvent) {
        DispatchQueue.main.async { [events] in
            events(event)
        }
    }
}

// MARK: - DFU Callbacks

extension FlashJob: DFUProgressDelegate, DFUServiceDelegate, LoggerDelegate {

    func dfuProgressDidChange(
        for part: Int,
        outOf totalParts: Int,
        to progress: Int,
        currentSpeedBytesPerSecond: Double,
        avgSpeedBytesPerSecond: Double
    ) {
        guard !isEnded else { return }
        emit(.progress(Double(progress) / 100.0))
    }

    func logWith(_ level: LogLevel, message: String) {
        LogNotify.log("DFU Message: \(message)")
    }

    func dfuStateDidChange(to state: DFUState) {
        LogNotify.log("DFU State change: \(state)")
        switch state {
        case .completed:
            complete()
        case .aborted:
            if Calliope.isConnectionSwitching {
                LogNotify.log("Connection switching - suppressing abort message")
                return
            }
            // Dismissing the export picker is no error, and the USB connection stays so the next flash reopens the picker.
            if (target as? USBCalliope)?.lastExportCancelledByUser == true {
                LogNotify.log("Export picker cancelled by user - suppressing abort message")
                guard !isEnded else { return }
                end()
                emit(.cancelled)
                return
            }
            dfuError(.deviceDisconnected, didOccurWithMessage: "DFU process aborted")
        default:
            break
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        LogNotify.log("DFU Error \(error) while uploading: \(message)")
        if Calliope.isConnectionSwitching {
            LogNotify.log("Connection switching - suppressing error message")
            return
        }
        fail(.dfu(message))
    }
}
