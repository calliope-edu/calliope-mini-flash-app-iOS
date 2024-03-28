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
        return [.universal, .v3, .v2]
    }
    
    public init(calliopeLocation: URL) throws {
        super.init()
        try validateCalliope(url: calliopeLocation)
        USBCalliope.calliopeLocation = calliopeLocation
    }
    
    func validateCalliope(url: URL) throws {
        let pathComponent = url.appendingPathComponent("DETAILS.TXT")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        url.startAccessingSecurityScopedResource()
        if fileManager.fileExists(atPath: filePath) {
            print("Validated Calliope folder")
        } else {
            LogNotify.log("Failed to Validate calliope")
        }
        url.stopAccessingSecurityScopedResource()
    }
    
    func isConnected() -> Bool {
        let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
        defer {
            if accessResource ?? false {
                USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
            }
        }
        
        if (USBCalliope.calliopeLocation == nil) {
            return false
        } else {
            return FileManager.default.isWritableFile(atPath: USBCalliope.calliopeLocation!.path)
        }
    }
    
    override func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        if isConnected(){
            writeToCalliope(file) {
                statusDelegate?.dfuStateDidChange(to: .completed)
            }
        } else {
            statusDelegate?.dfuStateDidChange(to: .aborted)
        }
        
    }

    fileprivate func writeToCalliope(_ file: Hex?, _ completion: @escaping () -> Void) {
        do {
            let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
            defer {
                if accessResource ?? false {
                    USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
                }
            }
            
            let data = Data()
            let startInterfaceCommand = "start_if.act"
            let resetCommand = "auto_rst.cfg"
            let startInterfaceCommandFile = USBCalliope.calliopeLocation!.appendingPathComponent(startInterfaceCommand)
            let resetCommandFile = USBCalliope.calliopeLocation!.appendingPathComponent(resetCommand)
            do {
                try data.write(to: startInterfaceCommandFile)
            } catch {
                print(error)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
                defer {
                    if accessResource ?? false {
                        USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    try data.write(to: resetCommandFile)
                } catch {
                    print(error)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
                defer {
                    if accessResource ?? false {
                        USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let data = try Data(contentsOf: file!.calliopeUSBUrl)
                    try data.write(to: USBCalliope.calliopeLocation!.appendingPathComponent(file!.calliopeUSBUrl.lastPathComponent))
                } catch {
                    print(error)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                completion()
            }
        } catch {
            print(error)
        }
    }
}
