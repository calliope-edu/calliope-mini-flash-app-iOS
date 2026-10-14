//
//  UploadViewModel.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class UploadViewModel: ObservableObject {

    @Published var isUploading = false
    @Published var progress: Double = 0.0  // 0.0 ... 1.0
    @Published var isExpanded = false
    @Published var isIndeterminate = false
    @Published var statusText = ""

    @Published var alert: AppAlert?
    @Published var isSharingLog = false
    var alertBinding: Binding<AppAlert?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }

    private let flashService: FlashService
    private let connection: DeviceConnectionService
    private let connectionPanel: MatrixConnectionViewModel

    private var cancelAction: (() -> Void)?
    // The flash whose progress is on screen; nil while the panel shows something else or nothing.
    private var progressFlashID: UUID?
    private var connectionLostSubscription: AnyCancellable?

    private static let hardwareInformationLink = "https://calliope.cc/programmieren/mobil/ipad#hardware"

    init(flashService: FlashService, connection: DeviceConnectionService, connectionPanel: MatrixConnectionViewModel) {
        self.flashService = flashService
        self.connection = connection
        self.connectionPanel = connectionPanel
        // Flashes are ended by FlashService; this covers progress shown for other jobs (data logger).
        connectionLostSubscription = connection.connectionLost.sink { [weak self] in
            guard let self, self.isUploading, self.progressFlashID == nil else { return }
            self.finishProgress()
        }
    }

    // MARK: - Uploads

    func upload(_ program: Hex, name: String? = nil, completion: (() -> Void)? = nil) {
        guard connection.currentCalliope != nil || (connectionPanel.isInUsbMode && connectionPanel.isSharedIpad) else {
            LogNotify.error("No calliope connected. Canceling upload.")
            alert = .cannotUpload()
            connectionPanel.animateBounce()
            return
        }
        alert = .uploadConfirmation(name: name, upload: { [weak self] in
            self?.uploadWithoutConfirmation(program, completion: completion)
        })
    }

    func upload(downloadable program: DownloadableHexFile) {
        if program.calliopeV1andV2Bin.count != 0 {
            upload(program)
            return
        }
        alert = .waitForProgramDownload()
        program.load { [weak self] error in
            DispatchQueue.main.async {
                self?.handleDownload(of: program, error: error)
            }
        }
    }

    var isUsbConnected: Bool {
        connection.isUsbConnected
    }

    func uploadWithoutConfirmation(_ program: Hex, completion: (() -> Void)? = nil) {
        if program.getHexTypes().contains(.arcade) && !isUsbConnected {
            alert = .arcadeUsbModeRequired(
                onOpenUsbMode: { [weak self] in
                    self?.openUsbMode()
                    self?.finish(completion)
                },
                onCancel: { [weak self] in
                    self?.finish(completion)
                }
            )
            return
        }

        let target = connection.currentCalliope
        let isUSB = target is USBCalliope
        // Export-picker failures are usually a stale USB volume, so they offer the log for reporting.
        let usesExportPicker = (target as? USBCalliope)?.useExportPicker == true
        LogNotify.debug("useExportPicker = \(usesExportPicker)")

        let flashID = UUID()
        flashService.flash(program) { [weak self] event in
            guard let self else { return }
            switch event {
            case .progress(let value):
                if self.progressFlashID != flashID {
                    // FlashService already dropped the previous flash; cancelling now would hit this one.
                    if self.progressFlashID != nil {
                        self.cancelAction = nil
                    }
                    self.startProgress(
                        isIndeterminate: value == nil,
                        statusText: value == nil ? NSLocalizedString("Transferring to Calliope", comment: "") : "",
                        cancel: { [weak self] in self?.flashService.cancel() }
                    )
                    self.progressFlashID = flashID
                } else if let value {
                    self.updateProgress(value)
                }
            case .completed, .cancelled:
                self.finishProgress(of: flashID)
                self.finish(completion)
            case .failed(let error):
                self.finishProgress(of: flashID)
                self.presentFailure(error, isUSB: isUSB, usesExportPicker: usesExportPicker)
            }
        }
    }

    // MARK: - Progress

    func startProgress(isIndeterminate: Bool = false, statusText: String = "", cancel: (() -> Void)? = nil) {
        if isUploading {
            LogNotify.debug("Started upload while another one is running. Canceling the current upload in favor of the new one.")
            self.cancel()
        }
        isUploading = true
        progress = 0.0
        isExpanded = false
        self.isIndeterminate = isIndeterminate
        self.statusText = statusText
        cancelAction = cancel
    }

    func updateProgress(_ value: Double) {
        if isUploading {
            progress = min(max(value, 0.0), 1.0)
        }
    }

    func finishProgress() {
        isUploading = false
        progress = 0.0
        isExpanded = false
        isIndeterminate = false
        statusText = ""
        cancelAction = nil
        progressFlashID = nil
    }

    func cancel() {
        cancelAction?()
        finishProgress()
    }

    // MARK: - Private Helpers

    private func finishProgress(of flashID: UUID) {
        if progressFlashID == flashID {
            finishProgress()
        }
    }

    private func finish(_ completion: (() -> Void)?) {
        connectionPanel.connect()
        completion?()
    }

    private func handleDownload(of program: DownloadableHexFile, error: Error?) {
        guard error == nil, program.calliopeV1andV2Bin.count != 0 else {
            LogNotify.error("Encountered error during program download: " + (error?.localizedDescription ?? ""))
            alert = .programDownloadFailed(error: error?.localizedDescription, completion: {})
            return
        }
        LogNotify.debug("Successfully finished downloading program")
        alert = .programDownloadSuccess(upload: { [weak self] in
            self?.uploadWithoutConfirmation(program)
        })
    }

    private func openUsbMode() {
        connectionPanel.menuExpanded = true
        connectionPanel.isInUsbMode = true
        // Lets the panel switch to USB before the folder picker opens.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [connectionPanel] in
            connectionPanel.startUsbConnect()
        }
    }

    private func presentFailure(_ error: UploadError, isUSB: Bool, usesExportPicker: Bool) {
        switch error {
        case .notConnected:
            alert = .cannotUpload()
            connectionPanel.animateBounce()
        case .connectionLost:
            break
        case .incompatibleHex:
            alert = .uploadFailed(goToInformation: Self.openHardwareInformation)
        case .dfu:
            if usesExportPicker {
                alert = .usbTransferFailed(
                    message: NSLocalizedString("The file could not be transferred. Unplug the Calliope mini and plug it in again before you transfer the next program.", comment: ""),
                    shareLog: { [weak self] in self?.isSharingLog = true }
                )
            } else if isUSB {
                alert = .usbUploadFailed()
            } else {
                alert = .uploadFailed(goToInformation: Self.openHardwareInformation)
            }
        case .transferRejected:
            alert = .usbTransferFailed(
                message: NSLocalizedString("There was an error transferring the file. Please try again. If the error persists, unplug the data cable and plug it back in.", comment: ""),
                shareLog: { [weak self] in self?.isSharingLog = true }
            )
        }
    }

    private static func openHardwareInformation() {
        if let url = URL(string: hardwareInformationLink) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Previews

    static func preview() -> UploadViewModel {
        let connection = PreviewDeviceConnectionService()
        return UploadViewModel(flashService: FlashService(connection: connection), connection: connection, connectionPanel: MatrixConnectionViewModel(connection: connection))
    }
}
