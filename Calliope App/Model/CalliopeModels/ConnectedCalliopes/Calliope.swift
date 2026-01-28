//
//  Calliope.swift
//  Calliope App
//
//  Created by itestra on 29.01.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import NordicDFU
import CoreBluetooth

class Calliope: NSObject, DFUServiceDelegate, CBPeripheralDelegate {

    // Flag um Fehlermeldungen bei Verbindungswechsel zu unterdrücken
    static var isConnectionSwitching = false
    
    /// Aufrufen wenn Verbindung gewechselt wird (BLE -> USB oder USB -> BLE)
    static func startConnectionSwitch() {
        isConnectionSwitching = true
        // Nach 5 Sekunden wieder deaktivieren
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isConnectionSwitching = false
        }
    }

    public var compatibleHexTypes: Set<HexParser.HexVersion> {
        []
    }

    internal var rebootingIntoDFUMode = false
    public internal(set) var shouldRebootOnDisconnect = false

    func dfuStateDidChange(to state: NordicDFU.DFUState) {
        return
    }

    func dfuError(_ error: NordicDFU.DFUError, didOccurWithMessage message: String) {
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
