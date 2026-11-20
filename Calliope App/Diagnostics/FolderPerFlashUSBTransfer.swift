//
//  FolderPerFlashUSBTransfer.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct FolderPerFlashUSBTransfer: USBTransferStrategy {

    let picker: DiagnosticsFolderPicker

    // There is no folder before the picker, so the copy itself has to show whether the mini is there.
    var isConnected: Bool {
        true
    }

    func transfer(_ source: URL, named name: String, onRejected: @escaping (String) -> Void, completion: @escaping (USBTransferOutcome) -> Void) {
        picker.pickFolder { result in
            switch result {
            case nil:
                LogNotify.log("USB Transfer: folder picker cancelled by user")
                completion(.cancelledByUser)
            case .failure(let error):
                LogNotify.log("USB Transfer: folder picker failed (\(error.localizedDescription))")
                completion(.failed)
            case .success(let folder):
                LogNotify.log("USB Transfer: picked folder \(folder.path), Calliope volume: \(USBCalliope.isCalliopeVolume(folder))")
                FolderUSBTransfer(folder: folder).transfer(source, named: name, onRejected: onRejected, completion: completion)
            }
        }
    }
}
