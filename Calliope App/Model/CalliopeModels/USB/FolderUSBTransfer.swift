//
//  FolderUSBTransfer.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct FolderUSBTransfer: USBTransferStrategy {

    let folder: URL

    var isConnected: Bool {
        (try? folder.checkResourceIsReachable()) ?? false
    }

    func transfer(_ source: URL, named name: String, onRejected: @escaping (String) -> Void, completion: @escaping (USBTransferOutcome) -> Void) {
        // Folder copies are not verified: iOS keeps a stale view of the volume for seconds, which made back-to-back flashes report false failures.
        USBHexWriter.write(source, to: folder.appendingPathComponent(name), securityScope: folder, coordination: .forReplacing, waitsForFile: false) { success in
            completion(success ? .written : .failed)
        }
    }
}
