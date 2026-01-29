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
        return [.universal, .v3, .v3Alt, .v2, .arcade]
    }
    
    var writeInProgress: Bool = false
    
    public init(calliopeLocation: URL) throws {
        super.init()
        // Verbindungswechsel signalisieren
        Calliope.startConnectionSwitch()
        
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
    /** Flashing process for USB Flashing
        Simplified: Direct file copy without DAPLink commands
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
        
        // Direkt die komplette Datei kopieren
        LogNotify.log("USB Transfer - copying complete file")
        do {
            let data = try Data(contentsOf: file.calliopeUSBUrl)
            try data.write(to: USBCalliope.calliopeLocation!.appendingPathComponent(file.calliopeUSBUrl.lastPathComponent))
            LogNotify.log("File copied successfully")
        } catch {
            LogNotify.log("Error copying file: \(error)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion()
        }
    }
    
}
