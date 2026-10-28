//
//  PickedFileUSBTransfer.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct PickedFileUSBTransfer: USBTransferStrategy {

    let picker: USBDestinationPicker

    // There is no volume URL before the picker, so the copy itself has to show whether the mini is there.
    var isConnected: Bool {
        true
    }

    func transfer(_ source: URL, named name: String, onRejected: @escaping (String) -> Void, completion: @escaping (USBTransferOutcome) -> Void) {
        picker.pickDestination(filename: name) { result in
            switch result {
            case nil:
                LogNotify.log("USB Transfer: export picker cancelled by user - keeping USB connection")
                completion(.cancelledByUser)
            case .failure(let error):
                LogNotify.log("USB Transfer: creating the placeholder failed (\(error.localizedDescription))")
                completion(.failed)
            case .success(let url):
                let expectedBytes = USBHexWriter.byteCount(of: source)
                // .forReplacing could make the file provider recreate the picked file instead of writing into it.
                USBHexWriter.write(source, to: url, securityScope: url, coordination: [], waitsForFile: true) { success in
                    completion(success ? .written : .failed)
                    if success {
                        Self.verifyFlashOutcome(destinationURL: url, expectedBytes: expectedBytes, onRejected: onRejected)
                    }
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Checks in the background what actually became of the transfer, logs it
    /// and reports a rejection to `onRejected`. Two independent signals are used:
    ///
    /// 1. **How much arrived.** The export picker grants access to exactly the
    ///    file it created, so its size can really be read — unlike anything else on the
    ///    volume. This is the only reliable window into what iOS delivered.
    /// 2. **DAPLink's verdict.** A `FAIL.TXT` in the volume root means the hex
    ///    was rejected. Reading it may be denied by the sandbox, so read access
    ///    is probed with `DETAILS.TXT` first — otherwise a missing `FAIL.TXT`
    ///    would look like success when we simply cannot see it.
    private static func verifyFlashOutcome(destinationURL: URL, expectedBytes: Int, onRejected: @escaping (String) -> Void) {
        let volumeRoot = destinationURL.deletingLastPathComponent()
        DispatchQueue.global(qos: .utility).async {
            pollDestinationDelivery(destinationURL, expectedBytes: expectedBytes)
            let daplink = pollForDAPLinkVerdict(volumeRoot: volumeRoot)

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
                onRejected(failureText)
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
}
