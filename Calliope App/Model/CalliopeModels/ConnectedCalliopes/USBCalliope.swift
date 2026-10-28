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

    private let transferStrategy: USBTransferStrategy

    init(destination: USBDestination) {
        self.destination = destination
        switch destination {
        case .folder(let url):
            transferStrategy = FolderUSBTransfer(folder: url)
        case .pickPerFlash(let picker):
            transferStrategy = PickedFileUSBTransfer(picker: picker)
        }
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
        transferStrategy.isConnected
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
        // Captured up front: on Shared iPad this USBCalliope is released once the copy is through.
        let onTransferRejected = self.onTransferRejected

        // Off the main thread: on Shared iPad the hex may have to be downloaded from iCloud first.
        DispatchQueue.global(qos: .userInitiated).async { [weak statusDelegate] in
            let available = Self.materializeIfNeeded(source)

            DispatchQueue.main.async {
                guard available else {
                    LogNotify.log("USB Transfer: \(source.lastPathComponent) is not available locally - aborting")
                    self.finishTransfer(success: false, statusDelegate: statusDelegate)
                    return
                }
                self.transferStrategy.transfer(source, named: name, onRejected: { onTransferRejected?($0) }) { outcome in
                    if outcome == .cancelledByUser {
                        self.lastExportCancelledByUser = true
                    }
                    self.finishTransfer(success: outcome == .written, statusDelegate: statusDelegate)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func finishTransfer(success: Bool, statusDelegate: DFUServiceDelegate?) {
        writeInProgress = false
        statusDelegate?.dfuStateDidChange(to: success ? .completed : .aborted)
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
