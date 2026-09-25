//
//  DiscoveredUSBCalliope.swift
//  Calliope App
//
//  Created by itestra on 01.02.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

class DiscoveredUSBDevice: DiscoveredDevice {
    /// Destination folder of the mini's mass-storage volume. `nil` in
    /// export-picker mode, where no folder URL can be obtained up front.
    let url: URL?

    /// On Shared iPad the picker cannot return a folder URL for mounted USB
    /// volumes (the system silently refuses the selection), so we connect
    /// "virtually" without a URL and let `USBCalliope` open a per-flash export
    /// picker instead.
    let useExportPicker: Bool

    init?(url: URL, name: String) {
        self.url = url
        self.useExportPicker = false
        super.init(name: name)
        if !validateCalliope(url: url) {

            return nil
        }

    }

    /// Creates a USB device entry that uses the export-picker flow for each
    /// flash. Used on Shared iPad where folder picking on mounted volumes is
    /// silently denied.
    init(exportPickerName name: String) {
        self.url = nil
        self.useExportPicker = true
        super.init(name: name)
    }

    func validateCalliope(url: URL) -> Bool {
        let pathComponent = url.appendingPathComponent("DETAILS.TXT")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        let isAccessing = url.startAccessingSecurityScopedResource()
        
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return fileManager.fileExists(atPath: filePath)
    }
}
