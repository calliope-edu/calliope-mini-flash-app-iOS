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

    var id: String { rawValue }

    var label: String {
        switch self {
        case .placeholderThenWrite:
            return "Placeholder, then write (current)"
        case .placeholderThenWriteWithoutDelay:
            return "Placeholder, then write without delay (7174000)"
        case .exporterWritesHex:
            return "Exporter writes the hex (0ff05b0)"
        }
    }

    func strategy(exportPicker: USBDestinationPicker) -> USBTransferStrategy {
        switch self {
        case .placeholderThenWrite:
            return PickedFileUSBTransfer(picker: exportPicker)
        case .placeholderThenWriteWithoutDelay:
            return PickedFileUSBTransfer(picker: exportPicker, writeDelay: 0)
        case .exporterWritesHex:
            return ExportedHexUSBTransfer(picker: exportPicker)
        }
    }
}
