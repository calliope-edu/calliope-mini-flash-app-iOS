//
//  ExportedHexUSBTransfer.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct ExportedHexUSBTransfer: USBTransferStrategy {

    let picker: USBDestinationPicker

    // There is no volume URL before the picker, so the copy itself has to show whether the mini is there.
    var isConnected: Bool {
        true
    }

    func transfer(_ source: URL, named name: String, onRejected: @escaping (String) -> Void, completion: @escaping (USBTransferOutcome) -> Void) {
        let contents: Data
        do {
            contents = try Data(contentsOf: source, options: [.uncached])
        } catch {
            LogNotify.log("USB Transfer: reading \(source.lastPathComponent) failed (\(error.localizedDescription))")
            completion(.failed)
            return
        }

        picker.pickDestination(filename: name, contents: contents) { result in
            switch result {
            case nil:
                LogNotify.log("USB Transfer: export picker cancelled by user")
                completion(.cancelledByUser)
            case .failure(let error):
                LogNotify.log("USB Transfer: exporting the hex failed (\(error.localizedDescription))")
                completion(.failed)
            case .success(let url):
                LogNotify.log("USB Transfer: exporter wrote \(contents.count) bytes to \(url.lastPathComponent) - DAPLink will program & reset")
                completion(.written)
                PickedFileUSBTransfer.verifyFlashOutcome(destinationURL: url, expectedBytes: contents.count, onRejected: onRejected)
            }
        }
    }
}
