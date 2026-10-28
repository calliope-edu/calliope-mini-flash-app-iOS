//
//  USBTransferMethod.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

enum USBTransferMethod: String, CaseIterable, Identifiable {
    case placeholderThenWrite
    case placeholderThenWriteWithoutDelay
    case exporterWritesHex
    case folderPickedPerFlash

    var id: String { rawValue }

    var label: String {
        switch self {
        case .placeholderThenWrite:
            return "fileExporter and write with delay (current)"
        case .placeholderThenWriteWithoutDelay:
            return "fileExporter and write without delay (7174000)"
        case .exporterWritesHex:
            return "fileExporter writes the hex (0ff05b0)"
        case .folderPickedPerFlash:
            return "filePicker and write (normal)"
        }
    }

    func strategy(exportPicker: USBDestinationPicker, folderPicker: DiagnosticsFolderPicker) -> USBTransferStrategy {
        switch self {
        case .placeholderThenWrite:
            return PickedFileUSBTransfer(picker: exportPicker)
        case .placeholderThenWriteWithoutDelay:
            return PickedFileUSBTransfer(picker: exportPicker, writeDelay: 0)
        case .exporterWritesHex:
            return ExportedHexUSBTransfer(picker: exportPicker)
        case .folderPickedPerFlash:
            return FolderPerFlashUSBTransfer(picker: folderPicker)
        }
    }
}
