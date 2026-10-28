//
//  USBHexWriter.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

enum USBHexWriter {

    // Without this delay the first flash after plug-in fails sporadically, because DAPLink may have not finished remounting
    static let remountDelay: TimeInterval = 0.25

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
    static func write(_ source: URL, to destination: URL, securityScope: URL, coordination: NSFileCoordinator.WritingOptions, waitsForFile: Bool, delay: TimeInterval = remountDelay, completion: @escaping (Bool) -> Void) {
        let expectedBytes = byteCount(of: source)

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            let accessed = securityScope.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    securityScope.stopAccessingSecurityScopedResource()
                }
            }

            // didPickDocumentsAt fires before iOS has finished creating the file on the slow USB volume.
            let ready = !waitsForFile || waitForFile(destination, timeout: 5)
            if !ready {
                LogNotify.log("USB Transfer: placeholder did not appear on the volume")
            }
            let copyOK = ready && sequentialCopy(from: source, to: destination, options: coordination)
            LogNotify.log("USB Transfer: writing \(expectedBytes) bytes to \(destination.lastPathComponent) \(copyOK ? "succeeded - DAPLink will program & reset" : "FAILED")")

            DispatchQueue.main.async {
                completion(copyOK)
            }
        }
    }

    static func byteCount(of file: URL) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? Int) ?? -1
    }

    // MARK: - Private Helpers

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

    private static func sequentialCopy(from sourceURL: URL, to destinationURL: URL, options: NSFileCoordinator.WritingOptions) -> Bool {
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
