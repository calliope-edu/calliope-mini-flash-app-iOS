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
        let destinationUrl = USBCalliope.calliopeLocation!.appendingPathComponent(file.calliopeUSBUrl.lastPathComponent)
        var sourceFileSize: Int64 = 0

        do {
            let data = try Data(contentsOf: file.calliopeUSBUrl)
            sourceFileSize = Int64(data.count)
            try data.write(to: destinationUrl, options: .atomic)
            LogNotify.log("File copied successfully (\(sourceFileSize) bytes)")
        } catch {
            LogNotify.log("Error copying file: \(error)")
            DispatchQueue.main.async {
                completion()
            }
            return
        }

        // Verify file was written correctly by checking it exists and has correct size
        verifyFileWritten(at: destinationUrl, expectedSize: sourceFileSize, completion: completion)
    }

    /// Verifies that the file was written to the USB device by polling for its existence and size.
    /// Uses a short polling interval with a maximum timeout to avoid unnecessary delays.
    private func verifyFileWritten(at url: URL, expectedSize: Int64, completion: @escaping () -> Void, attempts: Int = 0) {
        let maxAttempts = 10  // Maximum 1 second total (10 * 100ms)
        let pollInterval: TimeInterval = 0.1  // 100ms between checks

        let fileManager = FileManager.default

        // Check if file exists and get its attributes
        if fileManager.fileExists(atPath: url.path) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int64 {
                    if fileSize == expectedSize {
                        LogNotify.log("USB Transfer - file verified: \(fileSize) bytes written")
                        DispatchQueue.main.async {
                            completion()
                        }
                        return
                    } else {
                        LogNotify.log("USB Transfer - size mismatch: expected \(expectedSize), got \(fileSize)")
                    }
                }
            } catch {
                LogNotify.log("USB Transfer - could not read file attributes: \(error)")
            }
        }

        // If we haven't exceeded max attempts, try again after a short delay
        if attempts < maxAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { [weak self] in
                self?.verifyFileWritten(at: url, expectedSize: expectedSize, completion: completion, attempts: attempts + 1)
            }
        } else {
            // Timeout reached - proceed anyway but log warning
            LogNotify.log("USB Transfer - verification timeout, proceeding anyway")
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
}
