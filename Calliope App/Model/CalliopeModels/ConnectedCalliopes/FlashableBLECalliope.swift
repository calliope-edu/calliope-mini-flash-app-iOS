//
//  DFUCalliope.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import CoreBluetooth
import NordicDFU
import UIKit

class FlashableBLECalliope: CalliopeAPI {

    // MARK: common
    private var rebootingForPartialFlashing = false
    internal var isPartiallyFlashing = false

    // Optimized partial flashing manager with pipelining
    private var optimizedFlashingManager: OptimizedPartialFlashingManager?

    // Tracks whether DFU has completed successfully and we're waiting for reconnect
    private var dfuCompletedAwaitingReconnect = false
    
    internal private(set) var file: Hex?

    weak internal private(set) var progressReceiver: DFUProgressDelegate?
    weak internal private(set) var statusDelegate: DFUServiceDelegate?
    weak internal private(set) var logReceiver: LoggerDelegate?

    override func notify(aboutState newState: DiscoveredDevice.CalliopeBLEDeviceState) {
        LogNotify.log("Received notification about state change to \(newState)")
        
        switch newState {
        case .usageReady:
            if rebootingForPartialFlashing {
                updateQueue.async {
                    self.startPartialFlashing()
                }
            } else if dfuCompletedAwaitingReconnect {
                // Nach DFU wieder verbunden - Reset der Flags
                LogNotify.log("Reconnected after DFU completion!")
                dfuCompletedAwaitingReconnect = false
                shouldRebootOnDisconnect = false
            }
            
        case .discovered:
            if isPartiallyFlashing {
                LogNotify.log("Lost connection to Calliope mini during partial flashing")
                // Setze Flag auf false um weitere Fehler zu vermeiden
                isPartiallyFlashing = false
                DispatchQueue.main.async {
                    self.statusDelegate?.dfuError(.deviceDisconnected, didOccurWithMessage: "connection to calliope lost")
                }
            }
            // Bei DFU completion ist discovered normal - wir warten auf reconnect
            
        case .wrongMode:
            // Reset flags bei falschem Modus
            if !rebootingIntoDFUMode {
                shouldRebootOnDisconnect = false
                dfuCompletedAwaitingReconnect = false
            }
            
        default:
            break
        }
    }

    public override func cancelUpload() -> Bool {
        cancel = true  //cancels partial flashing on next callback of calliope
        optimizedFlashingManager?.cancel()
        optimizedFlashingManager = nil
        let success = uploader?.abort()  //cancels full flashing
        if success ?? false {
            uploader = nil
        }
        return success ?? false
    }

    // MARK: full flashing

    internal var initiator: DFUServiceInitiator? = nil
    internal var uploader: DFUServiceController? = nil

    override public func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        let hexTypes = file.getHexTypes()
        if hexTypes.contains(.arcade) {
            LogNotify.log("Arcade files cannot be uploaded via Bluetooth")
            statusDelegate?.dfuError(.unsupportedResponse, didOccurWithMessage: NSLocalizedString("Arcade-Dateien können nur per USB übertragen werden.", comment: ""))
            return
        }

        self.file = file
        self.progressReceiver = progressReceiver
        self.statusDelegate = statusDelegate
        self.logReceiver = logReceiver
        
        // Reset flags
        dfuCompletedAwaitingReconnect = false

        // Attempt partial flashing first if available
        LogNotify.log("Partial flashing service available: \(discoveredOptionalServices.contains(.partialFlashing))")
        if discoveredOptionalServices.contains(.partialFlashing) && file.partialFlashingInfo != nil {
            startPartialFlashing()
        } else {
            // NEU: shouldRebootOnDisconnect HIER auf true setzen für Reconnect nach DFU
            shouldRebootOnDisconnect = true
            try startFullFlashing()
        }
    }

    internal func startFullFlashing() throws {
    }

    internal func preparePairing() throws {
        //this apparently is necessary before DFU characteristic can be properly used
        //was like this in the old app version
        _ = try read(characteristic: .dfuControl)
    }

    internal func triggerDfuMode() throws {
        let data = Data([0x01])
        rebootingIntoDFUMode = true
        do {
            try write(data, for: .dfuControl)
        } catch {
            dfuError(.failedToConnect, didOccurWithMessage: "Could not start DFU mode")
            throw error
        }
    }

    internal func transferFirmware() {
        guard let initiator = initiator else {
            fatalError("Firmware has disappeared somehow")
        }

        LogNotify.log("Starting transfer with peripheral: \(peripheral)")
        uploader = initiator.start(target: peripheral)
    }


    // MARK: partial flashing

    //current calliope state
    var dalHash = Data()
    var currentProgramHash = Data()

    //data file and its properties
    var hexFileHash = Data()
    var hexProgramHash = Data()
    var partialFlashData: PartialFlashData?

    //current flash package data
    var startPackageNumber: UInt8 = 0
    var currentSegmentAddress: UInt16 = 0
    var currentDataToFlash: [(address: UInt16, data: Data)] = []

    //for GUI interaction
    var cancel: Bool = false
    var linesFlashed = 0

    override func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {
        guard characteristic == .partialFlashing else {
            super.handleValueUpdate(characteristic, value)
            return
        }
        //dispatch from ble queue to update queue to avoid deadlock
        updateQueue.async {
            // Route to optimized manager if active, otherwise use legacy path
            if let manager = self.optimizedFlashingManager, manager.isActive {
                manager.handleNotification(value)
            } else {
                self.handlePartialValueNotification(value)
            }
        }
    }

    func handlePartialValueNotification(_ value: Data) {

        if cancel {
            endTransmission()
            updateCallback("Received cancel call")
            return
        }

        updateCallback("Received notification from partial flashing service: \(value.hexEncodedString())")

        if value[0] == .STATUS {
            //requested the mode of the calliope
            receivedStatus(value[2] == .MODE_APPLICATION)
            return
        }

        if value[0] == .REGION && value[1] == .DAL_REGION {
            //requested dal hash and position
            dalHash = value[10..<18]
            updateCallback("Dal region from \(value[2..<6].hexEncodedString()) to \(value[6..<10].hexEncodedString())")
            receivedDalHash()
            return
        }

        if value[0] == .REGION && value[1] == .PROGRAM_REGION {
            currentProgramHash = value[10..<18]
            LogNotify.log("Program region: \(value[2..<6].hexEncodedString()) to \(value[6..<10].hexEncodedString()) - hash: \(currentProgramHash.hexEncodedString()) - new hash: \(hexProgramHash.hexEncodedString())")
            receivedProgramHash()
            return
        }

        if value[0] == .REGION && value[1] == .EMBEDDED_REGION {
            LogNotify.log("Soft region: \(value[2..<6].hexEncodedString()) to \(value[6..<10].hexEncodedString()) - hash: \(value[10..<18].hexEncodedString())")
            receivedEmbedHash()
            return
        }

        if value[0] == .WRITE {
            updateCallback("write status: \(Data([value[1]]).hexEncodedString())")
            if value[1] == .WRITE_FAIL {
                LogNotify.log("⚠️ WRITE_FAIL (0xAA) received! Out-of-order packet detected at line \(linesFlashed)")
                LogNotify.log("Last block sent: startPkg=\(startPackageNumber - UInt8(currentDataToFlash.count)), count=\(currentDataToFlash.count)")
                LogNotify.log("Segment addr was: 0x\(String(format: "%04X", currentSegmentAddress))")
                _ = cancelUpload()
                resendPackages()
            } else if value[1] == .WRITE_SUCCESS {
                sendNextPackages()
            } else {
                LogNotify.log("⚠️ Unknown write status: 0x\(String(format: "%02X", value[1]))")
                fallbackToFullFlash()
            }
            return
        }
    }

    func startPartialFlashing() {
        rebootingForPartialFlashing = false

        updateCallback("Start partial flashing")
        LogNotify.log("⏱️ Partial flashing started at \(Date())")

        guard let file = file,
            let partialFlashingInfo = file.partialFlashingInfo,
            let partialFlashingCharacteristic = getCBCharacteristic(.partialFlashing)
        else {
            LogNotify.log("Partial flashing not found")
            fallbackToFullFlash()
            return
        }

        peripheral.setNotifyValue(true, for: partialFlashingCharacteristic)

        //reset variables in case we use the same calliope object twice

        //current calliope state
        dalHash = Data()

        //data file and its properties
        hexFileHash = Data()
        hexProgramHash = Data()
        partialFlashData = nil

        //current flash package data
        startPackageNumber = 0
        currentSegmentAddress = 0
        currentDataToFlash = []

        //for GUI interaction
        cancel = false
        linesFlashed = 0

        hexFileHash = partialFlashingInfo.fileHash
        hexProgramHash = partialFlashingInfo.programHash
        partialFlashData = partialFlashingInfo.partialFlashData

        // request dal hash
        send(command: .REGION, value: Data([.DAL_REGION]))
    }

    private func receivedDalHash() {
        updateCallback("Received dal hash \(dalHash.hexEncodedString()), hash in hex file is \(hexFileHash.hexEncodedString())")
        guard dalHash == hexFileHash else {
            fallbackToFullFlash()
            return
        }

        // request status
        send(command: .STATUS)
    }

    func receivedStatus(_ needsRebootIntoBLEOnlyMode: Bool) {
        updateCallback("Received mode of Calliope mini, needs reboot: \(needsRebootIntoBLEOnlyMode)")
        if needsRebootIntoBLEOnlyMode {
            shouldRebootOnDisconnect = true
            rebootingForPartialFlashing = true
            //calliope is in application state and needs to be rebooted
            send(command: .REBOOT, value: Data([.MODE_BLE]))
        } else {
            //calliope is already in bluetooth state
            // request embedded hash
            isPartiallyFlashing = true
            send(command: .REGION, value: Data([.EMBEDDED_REGION]))
        }
    }

    private func receivedEmbedHash() {
        updateCallback("Received embed hash")
        // request program hash
        send(command: .REGION, value: Data([.PROGRAM_REGION]))
    }

    private func receivedProgramHash() {
        updateCallback("Received program hash \(hexProgramHash.hexEncodedString())")
        if currentProgramHash == hexProgramHash {
            linesFlashed = partialFlashData?.lineCount ?? Int.max  //set progress to 100%
            updateCallback("No changes to upload - program hash matches")
            LogNotify.log("Hash matches - no changes needed, sending TRANSMISSION_END")
            // Must send TRANSMISSION_END to tell device we're done
            endTransmission()
            statusDelegate?.dfuStateDidChange(to: .completed)
        } else {
            updateCallback("Partial flashing starts sending new program to Calliope mini")
            LogNotify.log("Hash mismatch - starting partial flash")

            // Use optimized pipelining if enabled
            if PartialFlashingConfig.enabled {
                startOptimizedPartialFlashing()
            } else {
                // Fall back to legacy sequential approach
                startPackageNumber = 0
                sendNextPackages()
            }
        }
    }

    private func startOptimizedPartialFlashing() {
        guard let partialFlashData = partialFlashData else {
            fallbackToFullFlash()
            return
        }

        LogNotify.log("Using optimized partial flashing with pipelining (maxBlocksInFlight=\(PartialFlashingConfig.maxBlocksInFlight))")

        let manager = OptimizedPartialFlashingManager(calliope: self)
        self.optimizedFlashingManager = manager

        manager.progressCallback = { [weak self] current, total in
            guard let self = self else { return }
            self.linesFlashed = current
            let percent = total > 0 ? Int((Double(current) / Double(total)) * 100) : 0
            self.progressReceiver?.dfuProgressDidChange(
                for: 1, outOf: 1, to: percent,
                currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0
            )
        }

        manager.completionCallback = { [weak self] success, message in
            guard let self = self else { return }
            LogNotify.log("Optimized partial flashing completed: success=\(success), message=\(message)")
            if success {
                // WICHTIG: Der OptimizedPartialFlashingManager hat bereits:
                // - isPartiallyFlashing auf false gesetzt
                // - shouldRebootOnDisconnect auf false gesetzt
                // - TRANSMISSION_END gesendet
                // Wir müssen nur noch .completed Signal geben
                self.statusDelegate?.dfuStateDidChange(to: .completed)
            } else {
                LogNotify.log("Optimized partial flashing failed, falling back to full flash")
                self.fallbackToFullFlash()
            }
        }

        manager.logCallback = { [weak self] message in
            self?.logReceiver?.logWith(.info, message: message)
        }

        manager.start(with: partialFlashData)
    }

    private func sendNextPackages() {
        guard var partialFlashData = partialFlashData else {
            fallbackToFullFlash()
            return
        }
        currentSegmentAddress = partialFlashData.currentSegmentAddress
        currentDataToFlash = []
        for _ in 0..<4 {
            guard let nextPackage = partialFlashData.next() else {
                break
            }
            currentDataToFlash.append(nextPackage)
        }
        self.partialFlashData = partialFlashData

        // Log every 50th package to track progress
        if linesFlashed % 50 == 0 || linesFlashed == 0 {
            LogNotify.log("Partial flashing: Sent \(linesFlashed)/\(partialFlashData.lineCount) packages (\(Int((Double(linesFlashed) / Double(partialFlashData.lineCount)) * 100))%)")
        }

        sendCurrentPackages()
        if currentDataToFlash.count < 4 {
            endTransmission()  //we did not have a full package to flash any more
            // WICHTIG: .completed wird erst in endTransmission() gerufen, nicht hier!
        }
        startPackageNumber = startPackageNumber.addingReportingOverflow(UInt8(currentDataToFlash.count)).partialValue
        linesFlashed += currentDataToFlash.count

        // ENTFERNT: Vorzeitige .completed Meldung führt zu Abbruch
        // if linesFlashed + 4 > partialFlashData.lineCount {
        //     statusDelegate?.dfuStateDidChange(to: .completed)
        // }
    }

    private func resendPackages() {
        fallbackToFullFlash()
    }

    private func sendCurrentPackages() {
        updateCallback("Sending \(currentDataToFlash.count) packages, beginning at \(startPackageNumber)")

        // Log detailed packet info for first block and every 50th block
        // TEMPORÄR: Aktiviere detailliertes Logging für alle Blöcke ab Block 35 für Debugging
        let shouldLogDetailed = (linesFlashed == 0 || linesFlashed % 50 == 0 || linesFlashed >= 140)

        if shouldLogDetailed {
            LogNotify.log("=== Block \(linesFlashed/4) Details ===")
            LogNotify.log("Segment Address: 0x\(String(format: "%04X", currentSegmentAddress))")
            for (idx, pkg) in currentDataToFlash.enumerated() {
                let dataPreview = pkg.data.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " ")
                LogNotify.log("  Pkg[\(idx)] addr=0x\(String(format: "%04X", pkg.address)) data=[\(dataPreview)...]")
            }
        }

        for (index, package) in currentDataToFlash.enumerated() {
            // WICHTIG: Das Original-Protokoll ist einfacher als gedacht:
            // - Paket 1 (index == 1): Verwende currentSegmentAddress (obere 16 Bit)
            // - Alle anderen Pakete (0, 2, 3): Verwende package.address (untere 16 Bit)
            // Dies ist das ORIGINAL-PROTOKOLL das funktioniert!
            let packageAddress = index == 1 ? currentSegmentAddress.bigEndianData : package.address.bigEndianData
            let packageNumber = Data([startPackageNumber + UInt8(index)])
            let writeData = packageAddress + packageNumber + package.data

            if shouldLogDetailed {
                let addrHex = packageAddress.map { String(format: "%02X", $0) }.joined()
                let numHex = String(format: "%02X", packageNumber[0])
                let dataHex = package.data.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " ")
                LogNotify.log("  → WRITE[\(index)] addr=[\(addrHex)] num=[\(numHex)] data=[\(dataHex)...]")
            }

            send(command: .WRITE, value: writeData)
        }
    }

    private func endTransmission() {
        // WICHTIG: Flags SOFORT setzen, bevor TRANSMISSION_END gesendet wird
        // Der Calliope könnte sich direkt nach Empfang von TRANSMISSION_END trennen
        isPartiallyFlashing = false
        shouldRebootOnDisconnect = false
        updateCallback("Partial flashing done!")
        LogNotify.log("⏱️ Partial flashing completed at \(Date())")

        // Kleine Verzögerung um Race Condition zu vermeiden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            // Send TRANSMISSION_END - device will reboot automatically
            self.send(command: .TRANSMISSION_END)
            LogNotify.log("TRANSMISSION_END sent - device should reboot automatically")
        }
    }


    //MARK: partial flashing utility functions

    private func send(command: UInt8, value: Data = Data()) {
        do {
            try writeWithoutResponse(Data([command]) + value, for: .partialFlashing)
        } catch {
            fallbackToFullFlash()
        }
    }

    private func fallbackToFullFlash() {
        isPartiallyFlashing = false
        updateCallback("Partial flash failed, resort to full flashing")
        do {
            try startFullFlashing()
        } catch {
            LogNotify.log("Full flashing failed, cancel upload")
            _ = cancelUpload()
        }
    }

    //MARK: partial flashing callbacks to GUI

    private func updateCallback(_ logMessage: String) {
        logReceiver?.logWith(.info, message: logMessage)
        let progressPerCent = Int(floor(Double(linesFlashed * 100) / Double(partialFlashData?.lineCount ?? Int.max)))
        LogNotify.log("Partial flashing progress: \(progressPerCent)%")
        progressReceiver?.dfuProgressDidChange(for: 1, outOf: 1, to: progressPerCent, currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0)
    }

    //MARK: dfu delegate

    override func dfuStateDidChange(to state: DFUState) {
        LogNotify.log("DFU State changed to: \(state)")
        
        switch state {
        case .starting:
            rebootingIntoDFUMode = false
            
        case .completed:
            // DFU erfolgreich abgeschlossen
            LogNotify.log("DFU completed successfully!")
            rebootingIntoDFUMode = false
            dfuCompletedAwaitingReconnect = true
            // WICHTIG: shouldRebootOnDisconnect auf true setzen damit Reconnect funktioniert
            shouldRebootOnDisconnect = true
            
        case .aborted:
            LogNotify.log("DFU was aborted")
            rebootingIntoDFUMode = false
            shouldRebootOnDisconnect = false
            dfuCompletedAwaitingReconnect = false
            
        case .disconnecting:
            // Der Calliope trennt sich nach DFU
            if dfuCompletedAwaitingReconnect {
                LogNotify.log("DFU disconnecting after successful flash - reconnect expected")
                // shouldRebootOnDisconnect bleibt true für Reconnect
            }
            
        default:
            break
        }
        
        statusDelegate?.dfuStateDidChange(to: state)
    }

    override func dfuError(_ error: NordicDFU.DFUError, didOccurWithMessage message: String) {
        LogNotify.log("DFU Error: \(error) - \(message)")
        rebootingIntoDFUMode = false
        shouldRebootOnDisconnect = false
        dfuCompletedAwaitingReconnect = false
        statusDelegate?.dfuError(error, didOccurWithMessage: message)
    }
}

//MARK: Calliope V1 and V2

class CalliopeV1AndV2: FlashableBLECalliope {

    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        [.universal, .v2]
    }

    override var requiredServices: Set<CalliopeService> {
        [.dfuControlService]
    }

    override var optionalServices: Set<CalliopeService> {
        [.partialFlashing]
    }

    override func notify(aboutState newState: DiscoveredDevice.CalliopeBLEDeviceState) {
        super.notify(aboutState: newState)
        if newState == .usageReady {
            //read to trigger pairing if necessary
            shouldRebootOnDisconnect = true
            if discoveredOptionalServices.contains(.partialFlashing), let cbCharacteristic = getCBCharacteristic(.partialFlashing) {
                peripheral.setNotifyValue(true, for: cbCharacteristic)
            }
            shouldRebootOnDisconnect = false
        }
    }

    internal override func startFullFlashing() throws {

        guard let file = file else {
            return
        }

        let bin = file.calliopeV1andV2Bin
        let dat = HexFile.calliopeV1AndV2InitPacket(bin)

        let firmware = DFUFirmware(binFile: bin, datFile: dat, type: .application)
        try preparePairing()

        initiator = DFUServiceInitiator().with(firmware: firmware)
        initiator?.logger = logReceiver
        initiator?.delegate = self
        initiator?.progressDelegate = progressReceiver

        try triggerDfuMode()

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.startDfuProcessDelay) {
            self.transferFirmware()
        }
    }
}

//MARK: Calliope V3

class CalliopeV3: FlashableBLECalliope {

    override func notify(aboutState newState: DiscoveredDevice.CalliopeBLEDeviceState) {
        super.notify(aboutState: newState)
        if newState == .usageReady {
            //read to trigger pairing if necessary
            shouldRebootOnDisconnect = true
            if let cbCharacteristic = getCBCharacteristic(.secureDfuCharacteristic) {
                peripheral.setNotifyValue(true, for: cbCharacteristic)
            }
            // Enable partial flashing notification for V3
            if discoveredOptionalServices.contains(.partialFlashing), let cbCharacteristic = getCBCharacteristic(.partialFlashing) {
                peripheral.setNotifyValue(true, for: cbCharacteristic)
            }
            shouldRebootOnDisconnect = false
        }
    }

    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        [.universal, .v3]
    }

    override var requiredServices: Set<CalliopeService> {
        [.secureDfuService]
    }

    // Enable partial flashing service for V3
    override var optionalServices: Set<CalliopeService> {
        [.partialFlashing]
    }

    internal override func startFullFlashing() throws {

        guard let file = self.file else {
            return
        }

        let bin = file.calliopeV3Bin
        let dat = try HexFile.calliopeV3InitPacket(bin)

        let firmware = DFUFirmware(binFile: bin, datFile: dat, type: .application)

        initiator = SecureDFUServiceInitiator().with(firmware: firmware)
        initiator?.logger = logReceiver
        initiator?.delegate = self
        initiator?.progressDelegate = progressReceiver
        initiator?.alternativeAdvertisingName = "DfuTarg"

        transferFirmware()
    }

    // Partial Flashing enabled for V3 with empty block filtering
    internal override func startPartialFlashing() {
        LogNotify.log("Starting partial flashing for V3")
        super.startPartialFlashing()
    }
}

//MARK: constants for partial flashing
extension UInt8 {
    //commands
    fileprivate static let REBOOT = UInt8(0xFF)
    fileprivate static let STATUS = UInt8(0xEE)
    fileprivate static let REGION = UInt8(0)
    fileprivate static let WRITE = UInt8(1)
    fileprivate static let TRANSMISSION_END = UInt8(2)

    //REGION parameters
    fileprivate static let EMBEDDED_REGION = UInt8(0)
    fileprivate static let DAL_REGION = UInt8(1)
    fileprivate static let PROGRAM_REGION = UInt8(2)

    //STATUS and REBOOT parameters
    fileprivate static let MODE_APPLICATION = UInt8(1)
    fileprivate static let MODE_BLE = UInt8(0)

    //WRITE response values
    fileprivate static let WRITE_FAIL = UInt8(0xAA)
    fileprivate static let WRITE_SUCCESS = UInt8(0xFF)
}
