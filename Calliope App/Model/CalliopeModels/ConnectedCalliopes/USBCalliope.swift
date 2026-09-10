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

class USBCalliope: Calliope, UIDocumentPickerDelegate {

    static var calliopeLocation: URL?

    /// Shared-iPad mode: instead of a persistent folder URL we present a
    /// `UIDocumentPickerViewController(forExporting:asCopy:)` for every flash.
    /// On Shared iPad with a Managed Apple ID the system silently rejects the
    /// folder pick of mounted USB volumes — the "Öffnen" button simply does
    /// nothing — so no security-scoped folder URL can ever be obtained. The
    /// export picker is the one flow the managed sandbox does allow.
    let useExportPicker: Bool

    /// View controller used to present the export picker. Set by FirmwareUpload
    /// before invoking `upload(...)`. Held weakly so we never retain UI state.
    weak var presentingController: UIViewController?

    // Retained while the export picker is on screen so its delegate stays alive.
    private var exportPickerInstance: UIDocumentPickerViewController?
    private weak var exportProgressReceiver: DFUProgressDelegate?
    private weak var exportStatusDelegate: DFUServiceDelegate?

    /// Temp copy of the hex carrying a DAPLink-friendly filename, handed to the
    /// export picker. Deleted once the picker finishes.
    private var stagedExportFileURL: URL?

    /// Set when the user dismissed the export picker without saving. The upload
    /// still has to report `.aborted` so `FirmwareUpload` can release the
    /// background task and idle timer, but a deliberate cancel is not an error —
    /// `FirmwareUpload` reads this to skip the failure alert and keep the
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

    /// Whether the export picker is pointed at the volume used last
    /// (`picker.directoryURL`), so the user does not have to navigate to MINI
    /// every time.
    ///
    /// **Currently off.** Field observation: the first transfer after a fresh
    /// install always worked, later ones often did not — and the pre-selection
    /// is exactly what differs, because on the first run there is no stored path
    /// yet. The stored path points into the file provider
    /// (`…/LiveFiles/com.apple.filesystems.userfsd/<UUID>/`), and DAPLink
    /// re-mounts its volume after every flash, so from the second transfer on
    /// the picker can be aimed at a handle that no longer refers to the device.
    ///
    /// Set to `true` to bring the convenience back if this turns out not to be
    /// the cause.
    static let preselectLastExportDirectory = false

    /// Directory the user last saved a hex into, remembered so the next export
    /// picker opens straight in it instead of the default location — normally
    /// the Calliope mini's "MINI" volume.
    ///
    /// iOS gives the app no way to learn about a mounted USB volume up front, so
    /// this can only take effect from the second transfer onwards. A stale path
    /// (volume unplugged, different device) is harmless: `directoryURL` is a
    /// hint, and the picker falls back to its default location.
    private static var lastExportDirectoryURL: URL? {
        get {
            guard let stored = UserDefaults.standard.string(forKey: "lastUsbExportDirectory") else {
                return nil
            }
            return URL(string: stored)
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: "lastUsbExportDirectory")
        }
    }


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

    /// Shared-iPad / export-picker initialiser. No folder pick happens; instead
    /// every flash opens an export picker so the user can pick MINI as the
    /// destination.
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

    /// Presents a system export picker for the hex file. The user picks the MINI
    /// volume as destination; iPadOS itself performs the copy with the
    /// entitlements it grants the picker — no `startAccessingSecurityScopedResource`
    /// and no folder URL needed, which is exactly why this works on Shared iPad
    /// while the folder picker does not.
    private func uploadViaExportPicker(file: Hex,
                                       progressReceiver: DFUProgressDelegate?,
                                       statusDelegate: DFUServiceDelegate?) {
        // Never stack a second picker on top of a running export. FirmwareUpload
        // shows no progress sheet in export mode, so nothing else stops a second
        // transfer request (a double tap on "Herunterladen", or the editor
        // firing its download handler twice) from opening another picker. Two
        // pickers meant two concurrent copies onto the same DAPLink volume,
        // which the Calliope mini reports as a flash error.
        if exportPickerInstance != nil {
            LogNotify.log("Export picker: already on screen - ignoring duplicate transfer request")
            // Treat like a cancel so FirmwareUpload releases its background task
            // and idle timer quietly, without showing a failure alert.
            lastExportCancelledByUser = true
            statusDelegate?.dfuStateDidChange(to: .aborted)
            return
        }

        guard let presenter = resolvePresentingController() else {
            LogNotify.log("Export picker: no presenting view controller available")
            statusDelegate?.dfuStateDidChange(to: .aborted)
            return
        }

        writeInProgress = true
        exportProgressReceiver = progressReceiver
        exportStatusDelegate = statusDelegate

        // Show indeterminate-ish progress so the FirmwareUpload alert reflects
        // that something is happening while the picker is on screen.
        progressReceiver?.dfuProgressDidChange(for: 50, outOf: 100, to: 30,
                                               currentSpeedBytesPerSecond: 0.0,
                                               avgSpeedBytesPerSecond: 0.0)

        // Export the hex under a DAPLink-friendly name (short, lowercase, no
        // spaces) instead of the project name. The picker takes the suggested
        // filename straight from the URL, and a long name with spaces invites
        // trouble on the FAT12 volume.
        //
        // Staging runs off the main thread because it may have to wait for the
        // hex to be downloaded from iCloud first (Shared iPad keeps programs in
        // the iCloud container).
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let staged = self?.stagedExportURL(for: file)

            DispatchQueue.main.async {
                guard let self = self else { return }

                // Deliberately NO fallback to `file.calliopeUSBUrl`. On Shared
                // iPad that is the iCloud-backed original; handing it to the
                // picker makes iOS materialise it while copying, which shows as
                // an indeterminate spinner and frequently ends in a truncated
                // transfer. Better to fail with a clear message than to open a
                // picker whose copy cannot succeed.
                guard let staged = staged else {
                    LogNotify.log("Export picker: no usable local copy of the hex - aborting instead of exporting the iCloud original")
                    self.lastExportCancelledByUser = false
                    self.finishExportPicker(success: false)
                    return
                }
                self.stagedExportFileURL = staged

                let picker = UIDocumentPickerViewController(forExporting: [staged], asCopy: true)
                picker.delegate = self
                picker.allowsMultipleSelection = false
                picker.shouldShowFileExtensions = true
                picker.modalPresentationStyle = .fullScreen
                // Open in the volume the user picked last (the MINI drive), so
                // they do not have to navigate there again for every transfer.
                if USBCalliope.preselectLastExportDirectory,
                   let lastDirectory = USBCalliope.lastExportDirectoryURL {
                    picker.directoryURL = lastDirectory
                }
                self.exportPickerInstance = picker
                presenter.present(picker, animated: true)
            }
        }
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

    /// Copies the hex into a temporary folder under a DAPLink-friendly filename
    /// and returns that URL, or `nil` if staging failed (caller then exports the
    /// original). The staged file is removed once the picker finishes.
    private func stagedExportURL(for file: Hex) -> URL? {
        USBCalliope.sweepStaleStagingDirectories()

        let source = file.calliopeUSBUrl
        let name = USBCalliope.sanitizedDAPLinkName(from: source.lastPathComponent)
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("usb-export-\(UUID().uuidString)", isDirectory: true)
        let destination = stagingDir.appendingPathComponent(name)
        if !USBCalliope.materializeIfNeeded(source) {
            LogNotify.log("Export picker: iCloud download of \(source.lastPathComponent) did not complete - the copy may be incomplete")
        }

        let sourceAttributes = try? FileManager.default.attributesOfItem(atPath: source.path)
        let sourceBytes = (sourceAttributes?[.size] as? Int) ?? -1

        do {
            try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: destination)
            let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path)
            let bytes = (attributes?[.size] as? Int) ?? -1

            // A copy from an iCloud placeholder can come back short without
            // throwing. Exporting a truncated hex is exactly what DAPLink then
            // reports as "checksum calculation failure", so refuse it here
            // instead of letting it reach the Calliope mini.
            if sourceBytes > 0, bytes != sourceBytes {
                LogNotify.log("Export picker: ⚠️ staged copy is incomplete (\(bytes) of \(sourceBytes) bytes) - discarding")
                try? FileManager.default.removeItem(at: stagingDir)
                return nil
            }

            LogNotify.log("Export picker: staged \(source.lastPathComponent) as \(name) (\(bytes) bytes)")
            return destination
        } catch {
            LogNotify.log("Export picker: staging failed (\(error.localizedDescription))")
            try? FileManager.default.removeItem(at: stagingDir)
            return nil
        }
    }

    /// Removes the staged export file — but only after a grace period.
    ///
    /// `didPickDocumentsAt` fires as soon as iOS has *accepted* the export, not
    /// when the bytes have actually landed on the (slow) USB mass-storage
    /// volume. Deleting the source right away can therefore truncate a copy that
    /// is still in flight, and DAPLink reports the result as
    /// "checksum calculation failure … type: transient" — intermittently,
    /// depending on timing. Keeping the staged file around costs nothing (it
    /// lives in the temp directory) and removes that race entirely.
    private func scheduleStagedExportCleanup() {
        guard let staged = stagedExportFileURL else { return }
        stagedExportFileURL = nil
        let stagingDir = staged.deletingLastPathComponent()
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 120) {
            try? FileManager.default.removeItem(at: stagingDir)
        }
    }

    /// Deletes staging folders left over from earlier exports (e.g. when the app
    /// was terminated before the deferred cleanup ran).
    private static func sweepStaleStagingDirectories() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: fm.temporaryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return }

        let cutoff = Date().addingTimeInterval(-600)   // older than 10 minutes
        for entry in entries where entry.lastPathComponent.hasPrefix("usb-export-") {
            let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified, modified > cutoff { continue }
            try? fm.removeItem(at: entry)
        }
    }

    private func resolvePresentingController() -> UIViewController? {
        if let pc = presentingController { return pc.topMostPresented() }
        // Fallback: walk the active scene's key window
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let keyWindow = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
            ?? scenes.flatMap { $0.windows }.first
        return keyWindow?.rootViewController?.topMostPresented()
    }

    private func finishExportPicker(success: Bool) {
        let progress = exportProgressReceiver
        let status = exportStatusDelegate
        exportPickerInstance = nil
        exportProgressReceiver = nil
        exportStatusDelegate = nil
        writeInProgress = false
        scheduleStagedExportCleanup()

        if success {
            progress?.dfuProgressDidChange(for: 100, outOf: 100, to: 100,
                                           currentSpeedBytesPerSecond: 0.0,
                                           avgSpeedBytesPerSecond: 0.0)
            status?.dfuStateDidChange(to: .completed)
        } else {
            status?.dfuStateDidChange(to: .aborted)
        }
    }

    // MARK: UIDocumentPickerDelegate (export-picker only — the folder picker is
    // handled in CalliopeDiscovery)

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard controller === exportPickerInstance else { return }
        LogNotify.log("Export picker: hex handed to \(urls.first?.path ?? "<unknown>")")
        lastExportCancelledByUser = false
        if let destination = urls.first {
            if USBCalliope.preselectLastExportDirectory {
                USBCalliope.lastExportDirectoryURL = destination.deletingLastPathComponent()
            }
        }

        // How many bytes we handed over — needed to judge what actually arrived.
        var expectedBytes = -1
        if let staged = stagedExportFileURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: staged.path),
           let size = attributes[.size] as? Int {
            expectedBytes = size
        }

        // Finish right away so nothing keeps the user waiting: the copy has been
        // handed over. The verdict only arrives seconds later and is checked in
        // the background.
        finishExportPicker(success: true)

        if let destination = urls.first {
            verifyFlashOutcome(destinationURL: destination, expectedBytes: expectedBytes)
        }
    }

    /// Checks in the background what actually became of the transfer and reports
    /// it. Two independent signals are used:
    ///
    /// 1. **How much arrived.** The picker grants access to exactly the file it
    ///    created, so its size can really be read — unlike anything else on the
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
                message: NSLocalizedString("USB transfer verification failed retry instructions", comment: "")),
            animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard controller === exportPickerInstance else { return }
        LogNotify.log("Export picker: cancelled by user - keeping USB connection")
        // A cancel is a deliberate user action, not a transfer failure. Flag it
        // so FirmwareUpload cleans up quietly instead of showing an error and
        // leaves the (virtual) USB connection in place.
        lastExportCancelledByUser = true
        finishExportPicker(success: false)
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
     3. `FileManager.copyItem` (= `copyfile(3)` = same as `/bin/cp`) — DAPLink
        sees the file appear with full contents in a single FAT transaction.
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

        let sourceURL = file.calliopeUSBUrl
        let safeName = Self.sanitizedDAPLinkName(from: sourceURL.lastPathComponent)
        let destinationURL = dirURL.appendingPathComponent(safeName)

        LogNotify.log("USB Transfer: queued copy \(sourceURL.lastPathComponent) → \(safeName)")

        // Estimate the perceived duration so the progress bar fills smoothly
        // and lands roughly when DAPLink finishes its work. Tuned by file size
        // because larger hex files (universal hex, ~600 KB+) take measurably
        // longer for the DAPLink chip programming phase that follows the copy.
        let fileBytes = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int)
            ?? 200_000
        let estimatedDuration = USBCalliope.estimateFlashDuration(forSourceBytes: fileBytes)
        startProgressAnimation(progressReceiver: progressReceiver, expectedDuration: estimatedDuration)

        // Brief settle delay: after `isConnected()` returns true, DAPLink may
        // still be finishing its MSD remount. Without this delay the first
        // flash after plug-in fails sporadically.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.25) { [weak self] in
            let acquired = dirURL.startAccessingSecurityScopedResource()
            let copyOK = USBCalliope.sequentialCopy(from: sourceURL, to: destinationURL)
            if acquired { dirURL.stopAccessingSecurityScopedResource() }

            if !copyOK {
                LogNotify.log("USB Transfer: FAILED to stream \(safeName)")
                DispatchQueue.main.async {
                    self?.finishProgressAnimation(progressReceiver: progressReceiver, success: false)
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
                self?.finishProgressAnimation(progressReceiver: progressReceiver, success: true)
                completion(true)
            }
        }
    }

    // MARK: - Progress animation
    //
    // FileManager.copyItem reports no progress, and we cannot interleave our
    // own progress hooks without breaking DAPLink (the parser starts on the
    // first byte that appears on the FAT, so any pre-write or chunked write
    // creates a 0-byte hex that DAPLink rejects with EIO).
    //
    // Instead we animate a smooth progress bar over the *typical* perceived
    // duration of a USB flash, which is dominated by the DAPLink hex parse +
    // chip programming phase (not the iOS copy itself). When the actual copy
    // returns, we jump the bar to 100 %.
    //
    // The result feels indistinguishable from real progress to the user —
    // similar in cadence to the existing Bluetooth flashing progress.

    private var progressTimer: DispatchSourceTimer?
    private var progressTickValue: Int = 0
    private var progressTotalTicks: Int = 1

    /// Heuristic: ~0.8 s baseline + scaling with file size.
    /// Measured on Calliope mini V3:
    ///   - 150 KB single-target hex → ~2.5 s total
    ///   - 600 KB universal hex     → ~4.5 s total
    ///   - 1 MB universal hex       → ~6.0 s total
    private static func estimateFlashDuration(forSourceBytes bytes: Int) -> TimeInterval {
        let baseline: TimeInterval = 0.8
        let perKilobyte: TimeInterval = 0.005      // 5 ms per KB
        return baseline + Double(bytes) / 1024.0 * perKilobyte
    }

    private func startProgressAnimation(progressReceiver: DFUProgressDelegate?,
                                        expectedDuration: TimeInterval) {
        stopProgressTimer()
        // Hold the ring at 0 % for 2 seconds before the animation begins —
        // gives the user a calmer perceived rhythm (matches the typical
        // pre-flash settling of DAPLink) and keeps the animation from feeling
        // hectic on small files.
        let startupDelay: TimeInterval = 2.0
        let tickInterval: TimeInterval = 0.1
        let totalTicks = max(1, Int(expectedDuration / tickInterval))
        progressTickValue = 0
        progressTotalTicks = totalTicks

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + startupDelay, repeating: tickInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.progressTickValue += 1
            // Animation tops out at 99 %. The final jump to 100 % comes from
            // finishProgressAnimation once the copy syscall actually returned.
            let percent = min(99, (self.progressTickValue * 99) / self.progressTotalTicks)
            progressReceiver?.dfuProgressDidChange(
                for: 50, outOf: 100,
                to: percent,
                currentSpeedBytesPerSecond: 0.0,
                avgSpeedBytesPerSecond: 0.0
            )
            if percent >= 99 {
                // Hold at 99 % until finishProgressAnimation fires — DAPLink
                // may simply be slower than our estimate on this device.
                self.progressTimer?.cancel()
                self.progressTimer = nil
            }
        }
        progressTimer = timer
        timer.resume()
    }

    private func finishProgressAnimation(progressReceiver: DFUProgressDelegate?, success: Bool) {
        stopProgressTimer()
        if success {
            progressReceiver?.dfuProgressDidChange(
                for: 50, outOf: 100,
                to: 100,
                currentSpeedBytesPerSecond: 0.0,
                avgSpeedBytesPerSecond: 0.0
            )
        }
        // On failure we leave the bar where it is; the error path drives the UI.
    }

    private func stopProgressTimer() {
        progressTimer?.cancel()
        progressTimer = nil
        progressTickValue = 0
        progressTotalTicks = 1
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

    /// Copies `sourceURL` to `destinationURL` via `FileManager.copyItem(at:to:)`
    /// wrapped in `NSFileCoordinator` with `.forReplacing` intent.
    ///
    /// **Why this combination is the only one that works for DAPLink:**
    ///
    /// DAPLink's MSD parser starts processing a `*.hex` file the instant it
    /// appears on the FAT. If we create the destination first and *then* write
    /// (FileHandle / chunked / streaming), DAPLink sees a 0-byte hex, marks the
    /// FAT entry as failed, and every subsequent `write(2)` returns `EIO`.
    /// `Data.write(to:, options: .atomic)` solves the 0-byte problem by writing
    /// to a non-.hex temp file and renaming, but the rename is unreliable on
    /// the DAPLink filesystem (causing the ~25 % failure rate we used to see).
    ///
    /// `FileManager.copyItem` on Apple platforms uses `copyfile(3)` — the same
    /// syscall `/bin/cp` uses on macOS, where DAPLink flashing works reliably.
    /// `copyfile` opens the destination with `O_WRONLY|O_CREAT|O_TRUNC`, writes
    /// the entire payload, and closes. DAPLink sees the file appear *with full
    /// contents* in a single FAT transaction, parses it, and programs the chip.
    ///
    /// `NSFileCoordinator(.forReplacing)` wraps the call so that the File
    /// Provider machinery (which DAPLink-via-Files-app runs through) acquires
    /// the right exclusive lock and tears down any cached observers.
    private static func sequentialCopy(from sourceURL: URL, to destinationURL: URL) -> Bool {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var success = false

        coordinator.coordinate(writingItemAt: destinationURL,
                               options: .forReplacing,
                               error: &coordError) { coordinatedURL in
            // Some DAPLink firmware revisions keep a stale FAT entry around
            // after a previous flash. Best-effort remove before copy.
            try? FileManager.default.removeItem(at: coordinatedURL)

            do {
                try FileManager.default.copyItem(at: sourceURL, to: coordinatedURL)
                success = true
            } catch {
                LogNotify.log("USB Transfer: copyItem failed: \(error)")
                // Fallback: copyItem can fail with file-provider quirks even when
                // a plain Data.write succeeds. Try the lower-level form once.
                if let data = try? Data(contentsOf: sourceURL, options: [.uncached]) {
                    do {
                        try data.write(to: coordinatedURL) // no .atomic — single open/write/close
                        success = true
                        LogNotify.log("USB Transfer: fallback Data.write succeeded")
                    } catch {
                        LogNotify.log("USB Transfer: fallback Data.write failed: \(error)")
                    }
                }
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
