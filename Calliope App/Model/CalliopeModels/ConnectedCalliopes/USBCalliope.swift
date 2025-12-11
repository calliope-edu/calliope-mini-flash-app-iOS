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

class USBCalliope: Calliope, UIDocumentPickerDelegate {

    static var calliopeLocation: URL?

    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        return [.universal, .v3, .v2, .arcade]
    }
    
    var writeInProgress: Bool = false

    public init(calliopeLocation: URL) throws {
        super.init()
        try validateCalliope(url: calliopeLocation)
        USBCalliope.calliopeLocation = calliopeLocation
    }

    func validateCalliope(url: URL) throws {
        let pathComponent = url.appendingPathComponent("DETAILS.TXT")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        let access = url.startAccessingSecurityScopedResource()

        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if fileManager.fileExists(atPath: filePath) {
            LogNotify.log("Validated Calliope mini folder")
        } else {
            LogNotify.log("Failed to validate Calliope mini")
        }
    }

    func isConnected() -> Bool {
        guard let calliopeLocation = USBCalliope.calliopeLocation else {
            return false
        }
        
        return (try? calliopeLocation.checkResourceIsReachable()) ?? false
    }

    override func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        if isConnected() || writeInProgress {
            if !writeInProgress { progressReceiver?.dfuProgressDidChange(for: 50, outOf: 100, to: 51, currentSpeedBytesPerSecond: 0.0, avgSpeedBytesPerSecond: 0.0) }
            writeInProgress = true
            writeToCalliope(file) {
                statusDelegate?.dfuStateDidChange(to: .completed)
                self.writeInProgress = false
            }
        } else {
            statusDelegate?.dfuStateDidChange(to: .aborted)
        }

    }

    /** Flashing process for USB Flashing
            1. Send "erase.act" to clean flash of Calliope
            2. Send "auto_rst.cfg" to enable auto restart after programming
            3. Send "start_if.act" to start interface mode
            4. Start flashing by copying file to calliope folder
        Between the different stages, Timeouts to allow for completion of processing
        For further information on the different commands, visit: https://github.com/ARMmbed/DAPLink/blob/main/docs/MSD_COMMANDS.md
     */
    fileprivate func writeToCalliope(_ file: Hex?, _ completion: @escaping () -> Void) {
        guard let file = file else {
            completion()
            return
        }
        
        let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
        defer {
            if accessResource ?? false {
                USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
            }
        }
        
        // Prüfen ob es eine Arcade-Datei ist
        let hexTypes = file.getHexTypes()
        let isArcadeFile = hexTypes.contains(.arcade)
        
        if isArcadeFile {
            // Arcade: Direkt die komplette Datei kopieren ohne vorherige Befehle
            LogNotify.log("Arcade file detected - copying complete file")
            do {
                let data = try Data(contentsOf: file.calliopeUSBUrl)
                try data.write(to: USBCalliope.calliopeLocation!.appendingPathComponent(file.calliopeUSBUrl.lastPathComponent))
                LogNotify.log("Arcade file copied successfully")
            } catch {
                LogNotify.log("Error copying Arcade file: \(error)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                completion()
            }
            return
        }
        
        // Bestehender Code für normale MakeCode-Dateien
        let data = Data()
        let startInterfaceCommand = "start_if.act"
        let autoRestartConfigurationCommand = "auto_rst.cfg"
        let eraseCommand = "erase.act"
        let startInterfaceCommandFile = USBCalliope.calliopeLocation!.appendingPathComponent(startInterfaceCommand)
        let autoRestartConfigurationCommandFile = USBCalliope.calliopeLocation!.appendingPathComponent(autoRestartConfigurationCommand)
        let eraseCommandFile = USBCalliope.calliopeLocation!.appendingPathComponent(eraseCommand)
        do {
            try data.write(to: eraseCommandFile)
        } catch {
            LogNotify.log("Error: \(error)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
            defer {
                if accessResource ?? false {
                    USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try data.write(to: autoRestartConfigurationCommandFile)
            } catch {
                LogNotify.log("Error: \(error)")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
            defer {
                if accessResource ?? false {
                    USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try data.write(to: startInterfaceCommandFile)
            } catch {
                LogNotify.log("Error: \(error)")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
            let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
            defer {
                if accessResource ?? false {
                    USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: file.calliopeUSBUrl)
                try data.write(to: USBCalliope.calliopeLocation!.appendingPathComponent(file.calliopeUSBUrl.lastPathComponent))
            } catch {
                LogNotify.log("Error: \(error)")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            completion()
        }
    }
}
