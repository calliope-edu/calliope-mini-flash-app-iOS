//
//  CalliopeUSBDiscovery.swift
//  Calliope App
//
//  Created by itestra on 29.01.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import NordicDFU
import UniformTypeIdentifiers

class USBCalliope: Calliope {

    static var calliopeLocation: URL?

    // Shared iPad refuses folder picks of USB volumes, so every flash goes through an export picker instead.
    let useExportPicker: Bool

    private weak var exportProgressReceiver: DFUProgressDelegate?
    private weak var exportStatusDelegate: DFUServiceDelegate?
    private var exportInProgress = false

    /// Set when the user dismissed the export picker without saving. The upload
    /// still has to report `.aborted` so `FlashJob` can release the
    /// background task and idle timer, but a deliberate cancel is not an error —
    /// `FlashJob` reads this to skip the failure alert and keep the
    /// connection, so the next flash goes straight back to the picker.
    private(set) var lastExportCancelledByUser = false

    /// DIAGNOSTICS (Shared-iPad USB investigation): when true, every transfer
    /// attempt ends with an alert showing DAPLink's verdict and the relevant log
    /// lines, with an option to share the full log. A Shared iPad can only be
    /// updated through TestFlight, where no console output is available.
    ///
    /// Set to `false` to go back to showing an alert only when the transfer
    /// actually failed.
    static let showTransferDiagnostics = false

    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        return [.universal, .v3, .v3Shield, .v2, .arcade]
    }

    var writeInProgress: Bool = false

    public init(calliopeLocation: URL) throws {
        self.useExportPicker = false
        super.init()
        // Verbindungswechsel signalisieren
        Calliope.startConnectionSwitch()

        try validateCalliope(url: calliopeLocation)
        USBCalliope.calliopeLocation = calliopeLocation
    }

    public init(exportPickerMode: Bool) {
        self.useExportPicker = exportPickerMode
        super.init()
        Calliope.startConnectionSwitch()
        USBCalliope.calliopeLocation = nil
    }


    func validateCalliope(url: URL) throws {
        let pathComponent = url.appendingPathComponent("DETAILS.TXT")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        let access = url.startAccessingSecurityScopedResource()
        
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        if fileManager.fileExists(atPath: filePath) {
            LogNotify.log("Validated Calliope mini folder")
        } else {
            LogNotify.log("Failed to validate Calliope mini")
        }
    }
    
    func isConnected() -> Bool {
        // In export-picker mode there is no persistent volume URL — the picker
        // is presented per-flash. Treat as always connected so upload proceeds.
        if useExportPicker {
            return true
        }
        guard let calliopeLocation = USBCalliope.calliopeLocation else {
            return false
        }

        return (try? calliopeLocation.checkResourceIsReachable()) ?? false
    }

    override func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        if useExportPicker {
            uploadViaExportPicker(file: file, progressReceiver: progressReceiver, statusDelegate: statusDelegate)
            return
        }
        if isConnected() || writeInProgress {
            writeInProgress = true
            writeToCalliope(file, progressReceiver: progressReceiver) { success in
                if success {
                    statusDelegate?.dfuStateDidChange(to: .completed)
                } else {
                    statusDelegate?.dfuStateDidChange(to: .aborted)
                }
                self.writeInProgress = false
            }
        } else {
            statusDelegate?.dfuStateDidChange(to: .aborted)
        }
    }

    // MARK: - Shared iPad: export-picker flashing

    // The system copy through the export picker fails on DAPLink, so the picker only creates an empty file and the app writes the hex into it.
    private func uploadViaExportPicker(file: Hex,
                                       progressReceiver: DFUProgressDelegate?,
                                       statusDelegate: DFUServiceDelegate?) {
        // Two pickers would mean two concurrent copies onto the same DAPLink volume.
        if exportInProgress {
            LogNotify.log("Export picker: already on screen - ignoring duplicate transfer request")
            // Treat like a cancel so FlashJob releases its background task
            // and idle timer quietly, without showing a failure alert.
            lastExportCancelledByUser = true
            statusDelegate?.dfuStateDidChange(to: .aborted)
            return
        }

        writeInProgress = true
        exportInProgress = true
        exportProgressReceiver = progressReceiver
        exportStatusDelegate = statusDelegate

        progressReceiver?.dfuProgressDidChange(for: 50, outOf: 100, to: 30,
                                               currentSpeedBytesPerSecond: 0.0,
                                               avgSpeedBytesPerSecond: 0.0)

        let source = file.calliopeUSBUrl
        // Off the main thread: on Shared iPad the hex may have to be downloaded from iCloud first.
        DispatchQueue.global(qos: .userInitiated).async {
            let available = USBCalliope.materializeIfNeeded(source)

            DispatchQueue.main.async {
                guard available else {
                    LogNotify.log("Export picker: \(source.lastPathComponent) is not available locally - aborting")
                    self.lastExportCancelledByUser = false
                    self.finishExportPicker(success: false)
                    return
                }
                let name = USBCalliope.sanitizedDAPLinkName(from: source.lastPathComponent)
                MatrixConnectionViewModel.instance.requestUsbExport(filename: name) { result in
                    self.handleExportResult(result, source: source)
                }
            }
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>?, source: URL) {
        switch result {
        case nil:
            LogNotify.log("Export picker: cancelled by user - keeping USB connection")
            lastExportCancelledByUser = true
            finishExportPicker(success: false)
        case .failure(let error):
            LogNotify.log("Export picker: creating the placeholder failed (\(error.localizedDescription))")
            lastExportCancelledByUser = false
            finishExportPicker(success: false)
        case .success(let destination):
            lastExportCancelledByUser = false
            let expectedBytes = ((try? FileManager.default.attributesOfItem(atPath: source.path))?[.size] as? Int) ?? -1
            DispatchQueue.global(qos: .userInitiated).async {
                let accessed = destination.startAccessingSecurityScopedResource()
                defer { if accessed { destination.stopAccessingSecurityScopedResource() } }
                LogNotify.log("Export picker: placeholder at \(destination.path), security scope granted: \(accessed)")

                let placeholderExists = USBCalliope.waitForFile(destination, timeout: 5)
                if !placeholderExists {
                    LogNotify.log("Export picker: placeholder did not appear on the volume")
                }
                // .forReplacing could make the file provider recreate the file instead of writing into it.
                let copyOK = placeholderExists && USBCalliope.sequentialCopy(from: source, to: destination, options: [])
                LogNotify.log("Export picker: app-side write of \(expectedBytes) bytes \(copyOK ? "succeeded" : "failed")")

                DispatchQueue.main.async {
                    self.finishExportPicker(success: copyOK)
                    if copyOK {
                        self.verifyFlashOutcome(destinationURL: destination, expectedBytes: expectedBytes)
                    }
                }
            }
        }
    }

    // didPickDocumentsAt fires before iOS has finished creating the file on the slow USB volume. Blocks — call off the main queue.
    private static func waitForFile(_ url: URL, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Forces an iCloud-backed file to download and waits (bounded) for it to
    /// become available locally. Returns `true` if the file is materialised, or
    /// was never an iCloud item. Blocks — call off the main queue.
    private static func materializeIfNeeded(_ url: URL, timeout: TimeInterval = 15) -> Bool {
        func isAvailable() -> Bool {
            guard let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
                  let status = values.ubiquitousItemDownloadingStatus else {
                return true      // not an iCloud item — nothing to wait for
            }
            return status == .current
        }

        if isAvailable() { return true }

        LogNotify.log("Export picker: hex is not available locally yet - requesting iCloud download")
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isAvailable() {
                LogNotify.log("Export picker: iCloud download finished")
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return isAvailable()
    }

    private func finishExportPicker(success: Bool) {
        let progress = exportProgressReceiver
        let status = exportStatusDelegate
        exportProgressReceiver = nil
        exportStatusDelegate = nil
        exportInProgress = false
        writeInProgress = false

        if success {
            progress?.dfuProgressDidChange(for: 100, outOf: 100, to: 100,
                                           currentSpeedBytesPerSecond: 0.0,
                                           avgSpeedBytesPerSecond: 0.0)
            status?.dfuStateDidChange(to: .completed)
        } else {
            status?.dfuStateDidChange(to: .aborted)
        }
    }

    /// Checks in the background what actually became of the transfer and reports
    /// it. Two independent signals are used:
    ///
    /// 1. **How much arrived.** The export picker grants access to exactly the
    ///    file it created, so its size can really be read — unlike anything else on the
    ///    volume. This is the only reliable window into what iOS delivered.
    /// 2. **DAPLink's verdict.** A `FAIL.TXT` in the volume root means the hex
    ///    was rejected. Reading it may be denied by the sandbox, so read access
    ///    is probed with `DETAILS.TXT` first — otherwise a missing `FAIL.TXT`
    ///    would look like success when we simply cannot see it.
    private func verifyFlashOutcome(destinationURL: URL, expectedBytes: Int) {
        let volumeRoot = destinationURL.deletingLastPathComponent()
        DispatchQueue.global(qos: .utility).async {
            let delivery = USBCalliope.pollDestinationDelivery(destinationURL, expectedBytes: expectedBytes)
            let daplink = USBCalliope.pollForDAPLinkVerdict(volumeRoot: volumeRoot)

            let verdict: String
            if let failureText = daplink.failureText {
                LogNotify.log("Export picker: DAPLink rejected the hex - \(failureText)")
                verdict = failureText
            } else if daplink.volumeReadable {
                LogNotify.log("Export picker: volume readable, no FAIL.TXT - transfer accepted")
                verdict = NSLocalizedString("The Calliope mini accepted the file.", comment: "Diagnostics verdict, success")
            } else {
                LogNotify.log("Export picker: cannot read the Calliope volume - outcome unknown")
                verdict = NSLocalizedString("The result cannot be verified: the app is not allowed to read the Calliope mini.", comment: "Diagnostics verdict, not verifiable")
            }

            DispatchQueue.main.async {
                if USBCalliope.showTransferDiagnostics {
                    FirmwareUpload.presentTransferDiagnosticsAlert(verdict: verdict + "\n" + delivery)
                    return
                }
                if daplink.failureText != nil {
                    USBCalliope.presentTransferFailureAlert()
                }
            }
        }
    }

    /// Watches the file iOS created on the volume and reports how much of it
    /// arrived. Blocks — call off the main queue.
    private static func pollDestinationDelivery(_ url: URL, expectedBytes: Int) -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let deadline = Date().addingTimeInterval(15)
        var lastSeen = -1

        while Date() < deadline {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int {
                lastSeen = size
                if expectedBytes > 0, size >= expectedBytes {
                    // NOTE: this is the file provider's own bookkeeping, and it
                    // reports the full size within milliseconds — far faster than
                    // a real write to the DAPLink mass-storage device could be.
                    // It therefore proves that iOS accepted the whole file, NOT
                    // that the bytes reached the Calliope mini.
                    LogNotify.log("Export picker: iOS reports \(size) of \(expectedBytes) bytes handed over (file provider bookkeeping, not a device confirmation)")
                    return "iOS accepted \(size) of \(expectedBytes) bytes (no confirmation from the Calliope mini)."
                }
            } else if lastSeen >= 0 {
                // DAPLink unmounts the volume once it starts programming, so the
                // file disappearing is expected — what matters is how much had
                // arrived by then.
                LogNotify.log("Export picker: destination vanished after \(lastSeen) of \(expectedBytes) bytes")
                return "Vanished after \(lastSeen) of \(expectedBytes) bytes."
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        LogNotify.log("Export picker: destination stalled at \(lastSeen) of \(expectedBytes) bytes")
        return "Stalled at \(lastSeen) of \(expectedBytes) bytes."
    }

    /// Polls for `FAIL.TXT` and, in parallel, establishes whether the volume can
    /// be read at all. Blocks — call off the main queue.
    private static func pollForDAPLinkVerdict(volumeRoot: URL) -> (failureText: String?, volumeReadable: Bool) {
        Thread.sleep(forTimeInterval: 2.0)

        let accessed = volumeRoot.startAccessingSecurityScopedResource()
        defer { if accessed { volumeRoot.stopAccessingSecurityScopedResource() } }

        let failURL = volumeRoot.appendingPathComponent("FAIL.TXT")
        let detailsURL = volumeRoot.appendingPathComponent("DETAILS.TXT")
        let deadline = Date().addingTimeInterval(10)
        var volumeReadable = false

        while Date() < deadline {
            if let data = try? Data(contentsOf: failURL, options: [.uncached]),
               let text = String(data: data, encoding: .utf8) {
                return (text.trimmingCharacters(in: .whitespacesAndNewlines), true)
            }
            // Reachability is not enough: the sandbox can allow stat() while
            // denying read(). DETAILS.TXT always exists on a DAPLink volume, so
            // reading it proves we could have seen a FAIL.TXT too.
            if !volumeReadable,
               (try? Data(contentsOf: detailsURL, options: [.uncached])) != nil {
                volumeReadable = true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return (nil, volumeReadable)
    }

    /// Shows the "transfer went wrong" hint. Static so it still works if this
    /// `USBCalliope` was released while we were waiting for DAPLink's verdict.
    private static func presentTransferFailureAlert() {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let keyWindow = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
            ?? scenes.flatMap { $0.windows }.first
        guard let presenter = keyWindow?.rootViewController?.topMostPresented() else { return }

        presenter.present(
            FirmwareUpload.makeUsbTransferFailureAlert(
                message: NSLocalizedString("There was an error transferring the file. Please try again. If the error persists, unplug the data cable and plug it back in.", comment: "")),
            animated: true)
    }


    /**
     USB flashing on Calliope mini (DAPLink-based) via the Files / Documents API.

     **DAPLink quirks that drive the implementation:**

     - DAPLink exposes a FAT12 mass-storage volume and parses an Intel-HEX file
       **as it streams in**. Writes must arrive in **sequential ascending offsets**.
       Any out-of-order delivery or rename-during-write fails the parse and DAPLink
       drops a `FAIL.TXT` instead of programming the chip.
     - `Data.write(to:, options: .atomic)` writes to a temp file with a random
       name and then renames it — both of those operations break DAPLink.
     - For large files (universal hex, ~600 KB) Foundation switches its internal
       write path to `sendfile`/`mmap`, which produces unordered burst writes.
       That is why universal hex *never* worked with the old code.
     - DAPLink **unmounts** the MSD volume immediately after a successful write
       to program the target and reset. The destination file therefore *vanishes*
       on success — verifying that the file still exists after the copy is
       misleading and was producing false negatives.

     **What we do here:**

     1. Resolve a safe FAT12-compatible destination name (8.3, ASCII).
     2. `NSFileCoordinator(.forReplacing)` to coordinate via File Provider.
     3. A single non-atomic `Data.write` — one open/write/close, no rename.
     4. Hold the security-scoped resource for the entire async operation.
     5. Treat a successful copy call as success. No post-write verification.
     */
    fileprivate func writeToCalliope(_ file: Hex?, progressReceiver: DFUProgressDelegate?, _ completion: @escaping (Bool) -> Void) {
        guard let file = file else {
            completion(false)
            return
        }
        guard let dirURL = USBCalliope.calliopeLocation else {
            LogNotify.log("USB Transfer: destination URL is nil")
            DispatchQueue.main.async { completion(false) }
            return
        }

        guard let calliopeLocation = USBCalliope.calliopeLocation else {
            LogNotify.log("USB Transfer - no known Calliope location")
            completion(false)
            return
        }

        let sourceURL = file.calliopeUSBUrl
        let safeName = Self.sanitizedDAPLinkName(from: sourceURL.lastPathComponent)
        let destinationURL = dirURL.appendingPathComponent(safeName)

        LogNotify.log("USB Transfer: queued copy \(sourceURL.lastPathComponent) → \(safeName)")

        // Without this delay the first flash after plug-in fails sporadically, because DAPLink may have not finished remounting
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.25) { [weak self] in
            let acquired = dirURL.startAccessingSecurityScopedResource()
            let copyOK = USBCalliope.sequentialCopy(from: sourceURL, to: destinationURL)
            if acquired { dirURL.stopAccessingSecurityScopedResource() }

            if !copyOK {
                LogNotify.log("USB Transfer: FAILED to stream \(safeName)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            // Copy succeeded — trust it. We used to additionally poll the volume
            // for DAPLink's unmount or remount as a "confirmation" signal, but
            // iOS's File Provider keeps a stale view of the URL for several
            // seconds after each flash. That made the *next* flash (e.g. after
            // switching editors) report a false failure even though DAPLink
            // had clearly programmed the chip. iOS's volume reachability is
            // simply not a reliable signal for back-to-back DAPLink flashes.
            //
            // Trade-off: if DAPLink later writes FAIL.TXT (invalid hex, wrong
            // board ID, etc.) we report success anyway. The user notices that
            // the calliope is still running the old program and retries. This
            // is rare; false failures on valid flashes were common.
            LogNotify.log("USB Transfer: file streamed to \(safeName) — DAPLink will program & reset")
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }



    /// FAT12-friendly file name: lowercase ASCII, max 8 chars + ".hex".
    /// DAPLink's MSD parser tolerates LFNs but parses 8.3 most reliably,
    /// especially for files coming from MakeCode with long project names
    /// (e.g. "microbit-My-Project-2026.hex").
    private static func sanitizedDAPLinkName(from filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension.lowercased()
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-_")
        let sanitized: String = String(base.compactMap { ch -> Character? in
            if allowed.contains(ch) { return ch }
            // map common separators to underscore, drop everything else
            if [" ", ".", "+", "(", ")", "[", "]"].contains(ch) { return "_" }
            return nil
        })
        let stem = sanitized.isEmpty ? "prog" : String(sanitized.prefix(4))
        // A fresh suffix for every transfer. DAPLink leaves the previously
        // written hex on its volume, so a fixed name makes iOS ask
        // "Vorhandene Objekte ersetzen?" — and if the user does not choose
        // "Ersetzen", iOS saves a duplicate ("… 2.hex"). The Calliope mini then
        // sees two hex files and the flash fails. A unique name avoids the
        // dialog (and the duplicate) altogether. Stays within 8.3: 4 + 4 chars.
        let suffix = String(format: "%04x", UInt16.random(in: 0...UInt16.max))
        return stem + suffix + ".hex"
    }

    private static func sequentialCopy(from sourceURL: URL, to destinationURL: URL, options: NSFileCoordinator.WritingOptions = .forReplacing) -> Bool {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var success = false

        coordinator.coordinate(writingItemAt: destinationURL,
                               options: options,
                               error: &coordError) { coordinatedURL in
            do {
                let data = try Data(contentsOf: sourceURL, options: [.uncached])
                // No .atomic: DAPLink breaks on the temp file + rename.
                try data.write(to: coordinatedURL)
                success = true
            } catch {
                LogNotify.log("USB Transfer: write failed: \(error)")
            }
        }

        if let err = coordError {
            LogNotify.log("USB Transfer: file coordination failed: \(err)")
            return false
        }
        return success
    }

}

extension UIViewController {
    /// Walks the chain of `presentedViewController` to find the top-most one,
    /// which is the only safe target for further `present(_:animated:)` calls.
    func topMostPresented() -> UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
