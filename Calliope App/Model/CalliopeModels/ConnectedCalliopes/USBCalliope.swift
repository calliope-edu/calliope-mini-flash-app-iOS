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
    /// On Shared iPad with Managed Apple ID the system silently rejects the
    /// folder pick of mounted USB volumes, so we cannot keep a security-scoped URL.
    let useExportPicker: Bool

    /// View controller used to present the export picker. Set by FirmwareUpload
    /// before invoking `upload(...)`. Held weakly so we never retain UI state.
    weak var presentingController: UIViewController?

    // Retained while the export picker is on screen so its delegate stays alive.
    private var exportPickerInstance: UIDocumentPickerViewController?
    private weak var exportProgressReceiver: DFUProgressDelegate?
    private weak var exportStatusDelegate: DFUServiceDelegate?

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
    /// every flash opens an export picker so the user can pick MINI as destination.
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
    /// volume as destination; iPadOS itself performs the copy with the entitlements
    /// it grants the picker — no `startAccessingSecurityScopedResource` needed.
    private func uploadViaExportPicker(file: Hex,
                                       progressReceiver: DFUProgressDelegate?,
                                       statusDelegate: DFUServiceDelegate?) {
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

        let picker = UIDocumentPickerViewController(forExporting: [file.calliopeUSBUrl], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .fullScreen
        exportPickerInstance = picker

        DispatchQueue.main.async {
            presenter.present(picker, animated: true)
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

        if success {
            progress?.dfuProgressDidChange(for: 100, outOf: 100, to: 100,
                                           currentSpeedBytesPerSecond: 0.0,
                                           avgSpeedBytesPerSecond: 0.0)
            status?.dfuStateDidChange(to: .completed)
        } else {
            status?.dfuStateDidChange(to: .aborted)
        }
    }

    // MARK: UIDocumentPickerDelegate (export-picker only — folder picker is handled in CalliopeDiscovery)

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard controller === exportPickerInstance else { return }
        LogNotify.log("Export picker: hex copied to \(urls.first?.path ?? "<unknown>")")
        finishExportPicker(success: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard controller === exportPickerInstance else { return }
        LogNotify.log("Export picker: cancelled by user")
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
        let trimmed = String(sanitized.prefix(8))
        return (trimmed.isEmpty ? "program" : trimmed) + ".hex"
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

private extension UIViewController {
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
