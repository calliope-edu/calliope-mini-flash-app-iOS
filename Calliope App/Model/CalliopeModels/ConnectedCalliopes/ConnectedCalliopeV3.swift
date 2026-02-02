//
//  ConnectedCalliopeV3.swift
//  Calliope App
//
//  Created by Jørn Alraun on 19.12.25.
//  Copyright © 2025 calliope. All rights reserved.
//
//  Diese Klasse repräsentiert einen Calliope mini V3 der im Application Mode läuft.
//  Sie hält die Verbindung aufrecht und kann bei Bedarf in den DFU Mode wechseln.
//

import CoreBluetooth
import NordicDFU
import UIKit

/// Ein Calliope V3 der im Application Mode verbunden ist (nach dem Flashen eines Programms).
/// Diese Klasse kann bei Bedarf automatisch in den DFU Mode wechseln um ein neues Programm zu flashen.
class ConnectedCalliopeV3: BLECalliope {
    
    // Im Application Mode akzeptieren wir den Calliope auch ohne DFU-Services
    // Wir benötigen nur den Partial Flashing Service um in den DFU Mode zu wechseln
    override var requiredServices: Set<CalliopeService> {
        []  // Keine required Services im Application Mode
    }
    
    override var optionalServices: Set<CalliopeService> {
        [.partialFlashing, .secureDfuService]
    }
    
    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        [.universal, .v3, .v3Shield]  // Unterstützt V3 Hex-Dateien (nach Wechsel in DFU Mode)
    }
    
    // MARK: - State Tracking
    
    /// Flag ob wir gerade auf Reboot in DFU Mode warten
    private var isRebootingToDFUMode = false
    
    /// Die Hex-Datei die nach dem Reboot geflasht werden soll
    private var pendingHexFile: Hex?
    private var pendingProgressReceiver: DFUProgressDelegate?
    private var pendingStatusDelegate: DFUServiceDelegate?
    private var pendingLogReceiver: LoggerDelegate?
    
    /// Callback wenn der DFU Mode erreicht wurde
    var onDFUModeReady: (() -> Void)?
    
    // MARK: - Initialization
    
    required init?(peripheral: CBPeripheral, name: String, discoveredServices: Set<CalliopeService>, discoveredCharacteristicUUIDsForServiceUUID: [CBUUID: Set<CBUUID>], servicesChangedCallback: @escaping () -> ()?) {
        super.init(peripheral: peripheral, name: name, discoveredServices: discoveredServices, discoveredCharacteristicUUIDsForServiceUUID: discoveredCharacteristicUUIDsForServiceUUID, servicesChangedCallback: servicesChangedCallback)
        
        LogNotify.log("ConnectedCalliopeV3 initialized - Calliope is in Application Mode")
    }
    
    // MARK: - State Notifications
    
    override func notify(aboutState newState: DiscoveredDevice.CalliopeBLEDeviceState) {
        LogNotify.log("ConnectedCalliopeV3: State changed to \(newState)")
        
        switch newState {
        case .usageReady:
            if isRebootingToDFUMode {
                // Wir sind nach dem Reboot wieder verbunden
                // Prüfe ob wir jetzt DFU-fähig sind
                if discoveredOptionalServices.contains(.secureDfuService) {
                    LogNotify.log("ConnectedCalliopeV3: Now in DFU Mode - ready to flash!")
                    isRebootingToDFUMode = false
                    onDFUModeReady?()
                    
                    // Wenn eine Hex-Datei wartet, starte das Flashing
                    if let hex = pendingHexFile {
                        startDFUFlashing(hex)
                    }
                } else {
                    LogNotify.log("ConnectedCalliopeV3: Still in Application Mode after reboot")
                }
            }
            
        case .discovered:
            if isRebootingToDFUMode {
                LogNotify.log("ConnectedCalliopeV3: Disconnected during DFU mode switch - waiting for reconnect")
            }
            
        default:
            break
        }
    }
    
    // MARK: - Upload Interface
    
    /// Startet den Upload einer Hex-Datei.
    /// Falls der Calliope im Application Mode ist, wird automatisch in den DFU Mode gewechselt.
    override public func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        
        // Prüfe ob Arcade-Datei (nicht per Bluetooth möglich)
        let hexTypes = file.getHexTypes()
        if hexTypes.contains(.arcade) {
            LogNotify.log("Arcade files cannot be uploaded via Bluetooth")
            statusDelegate?.dfuError(.unsupportedResponse, didOccurWithMessage: NSLocalizedString("Arcade-Dateien können nur per USB übertragen werden.", comment: ""))
            return
        }
        
        // Prüfe ob wir bereits DFU-fähig sind (Secure DFU Service verfügbar)
        if discoveredOptionalServices.contains(.secureDfuService) {
            LogNotify.log("ConnectedCalliopeV3: Already in DFU Mode - starting flash directly")
            // Wir haben den DFU Service - direkt flashen
            try startSecureDFU(file: file, progressReceiver: progressReceiver, statusDelegate: statusDelegate, logReceiver: logReceiver)
            return
        }
        
        // Wir sind im Application Mode - müssen erst in DFU Mode wechseln
        LogNotify.log("ConnectedCalliopeV3: In Application Mode - need to switch to DFU Mode first")
        
        // Speichere die Hex-Datei für später
        pendingHexFile = file
        pendingProgressReceiver = progressReceiver
        pendingStatusDelegate = statusDelegate
        pendingLogReceiver = logReceiver
        
        // Versuche in DFU Mode zu wechseln
        if !rebootIntoDFUMode() {
            // Reboot nicht möglich - informiere Nutzer
            LogNotify.log("ConnectedCalliopeV3: Cannot automatically switch to DFU Mode")
            statusDelegate?.dfuError(.deviceNotSupported, didOccurWithMessage: NSLocalizedString(
                "Bitte versetze den Calliope mini in den Bluetooth-Modus (A+B+Reset), um ein Programm zu übertragen.",
                comment: "Manual DFU mode instruction"
            ))
        }
    }
    
    // MARK: - DFU Mode Switch
    
    /// Versucht den Calliope in den DFU Mode zu rebooten
    /// - Returns: true wenn der Reboot-Befehl gesendet wurde, false wenn nicht möglich
    private func rebootIntoDFUMode() -> Bool {
        // Methode 1: Über Partial Flashing Service
        if discoveredOptionalServices.contains(.partialFlashing),
           let _ = getCBCharacteristic(.partialFlashing) {
            LogNotify.log("ConnectedCalliopeV3: Using Partial Flashing service to reboot into DFU Mode")
            return sendDFURebootCommand()
        }
        
        LogNotify.log("ConnectedCalliopeV3: No method available to switch to DFU Mode automatically")
        return false
    }
    
    /// Sendet den Reboot-Befehl über den Partial Flashing Service
    private func sendDFURebootCommand() -> Bool {
        // Partial Flashing Protokoll:
        // Command 0xFF = REBOOT
        // Parameter 0x00 = BLE/DFU Mode (0x01 wäre Application Mode)
        let REBOOT_COMMAND: UInt8 = 0xFF
        let MODE_BLE: UInt8 = 0x00
        
        do {
            isRebootingToDFUMode = true
            shouldRebootOnDisconnect = true  // Damit die Reconnect-Logik greift
            
            let rebootData = Data([REBOOT_COMMAND, MODE_BLE])
            try writeWithoutResponse(rebootData, for: .partialFlashing)
            
            LogNotify.log("ConnectedCalliopeV3: DFU Mode reboot command sent successfully")
            
            // Informiere über den Status
            pendingStatusDelegate?.dfuStateDidChange(to: .connecting)
            
            return true
            
        } catch {
            LogNotify.log("ConnectedCalliopeV3: Failed to send DFU reboot command: \(error)")
            isRebootingToDFUMode = false
            shouldRebootOnDisconnect = false
            return false
        }
    }
    
    // MARK: - DFU Flashing
    
    /// Startet das eigentliche DFU Flashing nachdem der DFU Mode erreicht wurde
    private func startDFUFlashing(_ file: Hex) {
        guard let progressReceiver = pendingProgressReceiver,
              let statusDelegate = pendingStatusDelegate else {
            LogNotify.log("ConnectedCalliopeV3: No pending delegates for DFU")
            return
        }
        
        do {
            try startSecureDFU(file: file, progressReceiver: progressReceiver, statusDelegate: statusDelegate, logReceiver: pendingLogReceiver)
        } catch {
            LogNotify.log("ConnectedCalliopeV3: Failed to start DFU: \(error)")
            statusDelegate.dfuError(.failedToConnect, didOccurWithMessage: error.localizedDescription)
        }
        
        // Clear pending data
        pendingHexFile = nil
        pendingProgressReceiver = nil
        pendingStatusDelegate = nil
        pendingLogReceiver = nil
    }
    
    /// Führt das Secure DFU für V3 durch
    private func startSecureDFU(file: Hex, progressReceiver: DFUProgressDelegate?, statusDelegate: DFUServiceDelegate?, logReceiver: LoggerDelegate?) throws {
        
        let bin = file.calliopeV3Bin
        let dat = try HexFile.calliopeV3InitPacket(bin)
        
        let firmware = DFUFirmware(binFile: bin, datFile: dat, type: .application)
        
        let initiator = SecureDFUServiceInitiator().with(firmware: firmware)
        initiator.logger = logReceiver
        initiator.delegate = self
        initiator.progressDelegate = progressReceiver
        initiator.alternativeAdvertisingName = "DfuTarg"
        
        LogNotify.log("ConnectedCalliopeV3: Starting Secure DFU transfer")
        let _ = initiator.start(target: peripheral)
    }
    
    // MARK: - DFU Delegate
    
    override func dfuStateDidChange(to state: DFUState) {
        LogNotify.log("ConnectedCalliopeV3: DFU state changed to \(state)")
        
        switch state {
        case .completed:
            // DFU erfolgreich - wir werden gleich disconnected und reconnected
            shouldRebootOnDisconnect = true
            
        case .aborted:
            shouldRebootOnDisconnect = false
            isRebootingToDFUMode = false
            
        default:
            break
        }
        
        pendingStatusDelegate?.dfuStateDidChange(to: state)
    }
    
    override func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        LogNotify.log("ConnectedCalliopeV3: DFU error: \(error) - \(message)")
        shouldRebootOnDisconnect = false
        isRebootingToDFUMode = false
        pendingStatusDelegate?.dfuError(error, didOccurWithMessage: message)
    }
}
