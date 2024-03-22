//
//  CalliopeUSBDiscovery.swift
//  Calliope App
//
//  Created by itestra on 29.01.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import iOSDFULibrary
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
            writeToCalliope(file)
            statusDelegate?.dfuStateDidChange(to: .completed)
        } else {
            statusDelegate?.dfuStateDidChange(to: .aborted)
        }
        
    }

    fileprivate func writeToCalliope(_ file: Hex?) {
        do {
            let accessResource = USBCalliope.calliopeLocation?.startAccessingSecurityScopedResource()
            defer {
                if accessResource ?? false {
                    USBCalliope.calliopeLocation?.stopAccessingSecurityScopedResource()
                }
            }
            try FileManager.default.copyItem(at: file!.callioeUSBUrl, to: USBCalliope.calliopeLocation!.appendingPathComponent(file!.callioeUSBUrl.lastPathComponent))
        } catch {
            print(error)
        }
    }
}
