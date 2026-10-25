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

    let destination: USBDestination

    // Set when the user dismissed the export picker: FlashJob then reports a cancel instead of an error and keeps the connection.
    private(set) var lastExportCancelledByUser = false

    // DAPLink's verdict arrives after the upload already reported completion.
    var onTransferRejected: ((String) -> Void)?

    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        return [.universal, .v3, .v3Shield, .v2, .arcade]
    }

    private(set) var writeInProgress: Bool = false

    private struct Target {
        let url: URL
        let securityScope: URL
        let coordination: NSFileCoordinator.WritingOptions
        let isPicked: Bool
    }

    init(destination: USBDestination) {
        self.destination = destination
        super.init()
        Calliope.startConnectionSwitch()
    }

    static func isCalliopeVolume(_ url: URL) -> Bool {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("DETAILS.TXT").path)
    }

    func isConnected() -> Bool {
        switch destination {
        case .folder(let url):
            return (try? url.checkResourceIsReachable()) ?? false
        case .pickPerFlash:
            // There is no volume URL before the picker, so the copy itself has to show whether the mini is there.
            return true
        }
    }

    override func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        // A second picker would mean two concurrent copies onto the same DAPLink volume.
        if writeInProgress && destination.picksPerFlash {
            LogNotify.log("USB Transfer: export picker already on screen - ignoring duplicate request")
            // Reported like a cancel so FlashJob ends quietly without a failure alert.
            lastExportCancelledByUser = true
            statusDelegate?.dfuStateDidChange(to: .aborted)
            return
        }
        guard isConnected() || writeInProgress else {
            statusDelegate?.dfuStateDidChange(to: .aborted)
            return
        }

        writeInProgress = true
        lastExportCancelledByUser = false
        let source = file.calliopeUSBUrl
        let name = Self.sanitizedDAPLinkName(from: source.lastPathComponent)
        LogNotify.log("USB Transfer: queued copy \(source.lastPathComponent) → \(name)")

        // Off the main thread: on Shared iPad the hex may have to be downloaded from iCloud first.
        DispatchQueue.global(qos: .userInitiated).async { [weak statusDelegate] in
            let available = Self.materializeIfNeeded(source)

            DispatchQueue.main.async {
                guard available else {
                    LogNotify.log("USB Transfer: \(source.lastPathComponent) is not available locally - aborting")
                    self.finishTransfer(success: false, statusDelegate: statusDelegate)
                    return
                }
                self.resolveTarget(named: name) { target in
                    guard let target else {
                        self.finishTransfer(success: false, statusDelegate: statusDelegate)
                        return
                    }
                    self.writeHex(source, to: target, statusDelegate: statusDelegate)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func resolveTarget(named name: String, completion: @escaping (Target?) -> Void) {
        switch destination {
        case .folder(let folder):
            completion(Target(url: folder.appendingPathComponent(name), securityScope: folder, coordination: .forReplacing, isPicked: false))
        case .pickPerFlash(let picker):
            picker.pickDestination(filename: name) { result in
                switch result {
                case nil:
                    LogNotify.log("USB Transfer: export picker cancelled by user - keeping USB connection")
                    self.lastExportCancelledByUser = true
                    completion(nil)
                case .failure(let error):
                    LogNotify.log("USB Transfer: creating the placeholder failed (\(error.localizedDescription))")
                    completion(nil)
                case .success(let url):
                    // .forReplacing could make the file provider recreate the picked file instead of writing into it.
                    completion(Target(url: url, securityScope: url, coordination: [], isPicked: true))
                }
            }
        }
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
     */
    private func writeHex(_ source: URL, to target: Target, statusDelegate: DFUServiceDelegate?) {
        let expectedBytes = ((try? FileManager.default.attributesOfItem(atPath: source.path))?[.size] as? Int) ?? -1

        // Without this delay the first flash after plug-in fails sporadically, because DAPLink may have not finished remounting
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.25) { [weak statusDelegate] in
            let accessed = target.securityScope.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    target.securityScope.stopAccessingSecurityScopedResource()
                }
            }

            // didPickDocumentsAt fires before iOS has finished creating the file on the slow USB volume.
            let ready = !target.isPicked || Self.waitForFile(target.url, timeout: 5)
            if !ready {
                LogNotify.log("USB Transfer: placeholder did not appear on the volume")
            }
            let copyOK = ready && Self.sequentialCopy(from: source, to: target.url, options: target.coordination)
            LogNotify.log("USB Transfer: writing \(expectedBytes) bytes to \(target.url.lastPathComponent) \(copyOK ? "succeeded - DAPLink will program & reset" : "FAILED")")

            DispatchQueue.main.async {
                self.finishTransfer(success: copyOK, statusDelegate: statusDelegate)
                // Folder copies are not verified: iOS keeps a stale view of the volume for seconds, which made back-to-back flashes report false failures.
                if copyOK && target.isPicked {
                    self.verifyFlashOutcome(destinationURL: target.url, expectedBytes: expectedBytes)
                }
            }
        }
    }

    private func finishTransfer(success: Bool, statusDelegate: DFUServiceDelegate?) {
        writeInProgress = false
        statusDelegate?.dfuStateDidChange(to: success ? .completed : .aborted)
    }

    // Blocks — call off the main queue.
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

    /// Checks in the background what actually became of the transfer, logs it
    /// and reports a rejection to `onTransferRejected`. Two independent signals are used:
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
        // Captured up front: on Shared iPad this USBCalliope is released once the copy is through.
        let onTransferRejected = self.onTransferRejected
        DispatchQueue.global(qos: .utility).async {
            USBCalliope.pollDestinationDelivery(destinationURL, expectedBytes: expectedBytes)
            let daplink = USBCalliope.pollForDAPLinkVerdict(volumeRoot: volumeRoot)

            guard let failureText = daplink.failureText else {
                if daplink.volumeReadable {
                    LogNotify.log("Export picker: volume readable, no FAIL.TXT - transfer accepted")
                } else {
                    LogNotify.log("Export picker: cannot read the Calliope volume - outcome unknown")
                }
                return
            }
            LogNotify.log("Export picker: DAPLink rejected the hex - \(failureText)")
            DispatchQueue.main.async {
                onTransferRejected?(failureText)
            }
        }
    }

    /// Watches the file iOS created on the volume and logs how much of it
    /// arrived. Blocks — call off the main queue.
    private static func pollDestinationDelivery(_ url: URL, expectedBytes: Int) {
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
                    return
                }
            } else if lastSeen >= 0 {
                // DAPLink unmounts the volume once it starts programming, so the
                // file disappearing is expected — what matters is how much had
                // arrived by then.
                LogNotify.log("Export picker: destination vanished after \(lastSeen) of \(expectedBytes) bytes")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        LogNotify.log("Export picker: destination stalled at \(lastSeen) of \(expectedBytes) bytes")
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
