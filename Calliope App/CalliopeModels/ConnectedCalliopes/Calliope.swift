//
//  Calliope.swift
//  Calliope App
//
//  Created by itestra on 29.01.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import iOSDFULibrary
import CoreBluetooth

class Calliope: NSObject, DFUServiceDelegate, CBPeripheralDelegate {
    
    public var compatibleHexTypes : Set<HexParser.HexVersion> { [] }
    
    internal var rebootingIntoDFUMode = false
    public internal(set) var shouldRebootOnDisconnect = false
    
    func dfuStateDidChange(to state: iOSDFULibrary.DFUState) {
        return
    }
    
    func dfuError(_ error: iOSDFULibrary.DFUError, didOccurWithMessage message: String) {
        return
    }
    
    public func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        fatalError("Raw use of calliope not implemented")
    }
    
    public func cancelUpload() -> Bool {
        return false
    }
    
    func notify(aboutState newState: DiscoveredDevice.CalliopeBLEDeviceState) {
    }
}
