//
//  DFUCalliope.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import UIKit
import CoreBluetooth
import NordicDFU

class FlashableBLECalliope: BLECalliope {
    
    // MARK: common
    private var rebootingForPartialFlashing = false
    private var isPartiallyFlashing = false
    
    internal private(set) var file: Hex?
    
    weak internal private(set) var progressReceiver: DFUProgressDelegate?
    weak internal private(set) var statusDelegate: DFUServiceDelegate?
    weak internal private(set) var logReceiver: LoggerDelegate?

    override func notify(aboutState newState: DiscoveredDevice.CalliopeBLEDeviceState) {
        LogNotify.log("Received notification about state change to \(newState)")
        if newState == .usageReady && rebootingForPartialFlashing {
            updateQueue.async {
                self.startPartialFlashing()
            }
        } else if newState == .discovered && isPartiallyFlashing {
            LogNotify.log("Lost connection to calliope during flashing process")
            // Abort if in discovered state but not in DfuProcess, however if is partial flashing
            DispatchQueue.main.async {
                self.statusDelegate?.dfuError(.deviceDisconnected, didOccurWithMessage: "connection to calliope lost")
            }
        }
    }
    
    public override func cancelUpload() -> Bool {
        cancel = true //cancels partial flashing on next callback of calliope
        let success = uploader?.abort() //cancels full flashing
        if success ?? false {
            uploader = nil
        }
        return success ?? false
    }
    
    // MARK: full flashing
    
    internal var initiator: DFUServiceInitiator? = nil
    internal var uploader: DFUServiceController? = nil
    
    override public func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        
        self.file = file
        
        self.progressReceiver = progressReceiver
        self.statusDelegate = statusDelegate
        self.logReceiver = logReceiver
        
        //Attempt partial flashing first
        // Android implementation: https://github.com/microbit-sam/microbit-android/blob/partial-flash/app/src/main/java/com/samsung/microbit/service/PartialFlashService.java
        // Explanation: https://lancaster-university.github.io/microbit-docs/ble/partial-flashing-service/
        // the explanation is outdated though.
        
        //Partial flashing deactivated for now. Calliope mini disconnects from device with MakeCode Beta Hex File.
        LogNotify.log("Partial flashing service available: \(discoveredOptionalServices.contains(.partialFlashing))")
        if discoveredOptionalServices.contains(.partialFlashing) {
            startPartialFlashing()
        } else {
            shouldRebootOnDisconnect = false
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
            fatalError("firmware has disappeared somehow")
        }
        
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
            return
        }
        //dispatch from ble queue to update queue to avoid deadlock
        updateQueue.async {
            self.handlePartialValueNotification(value)
        }
    }
    
    func handlePartialValueNotification(_ value: Data) {
        
        if cancel {
            endTransmission()
            updateCallback("received cancel call")
            return
        }
        
        updateCallback("received notification from partial flashing service: \(value.hexEncodedString())")
        
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
                resendPackages()
            } else if value[1] == .WRITE_SUCCESS {
                sendNextPackages()
            } else {
                //we do not understand the response
                fallbackToFullFlash()
            }
            return
        }
    }


    func startPartialFlashing() {
        rebootingForPartialFlashing = false

        updateCallback("start partial flashing")
        guard let file = file,
              let partialFlashingInfo = file.partialFlashingInfo,
              let partialFlashingCharacteristic = getCBCharacteristic(.partialFlashing) else {
            LogNotify.log("partialFlashing not found")
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
        updateCallback("received dal hash \(dalHash.hexEncodedString()), hash in hex file is \(hexFileHash.hexEncodedString())")
        guard dalHash == hexFileHash else {
            fallbackToFullFlash()
            return
        }
        
        // request status
        send(command: .STATUS)
    }
    
    func receivedStatus(_ needsRebootIntoBLEOnlyMode: Bool) {
        updateCallback("received mode of calliope, needs reboot: \(needsRebootIntoBLEOnlyMode)")
        if (needsRebootIntoBLEOnlyMode) {
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
        updateCallback("received embed hash")
        // request program hash
        send(command: .REGION, value: Data([.PROGRAM_REGION]))
    }
    
    private func receivedProgramHash() {
        updateCallback("received program hash \(hexProgramHash.hexEncodedString())")
        if currentProgramHash == hexProgramHash {
            linesFlashed = partialFlashData?.lineCount ?? Int.max //set progress to 100%
            updateCallback("no changes to upload")
            let _ = cancelUpload() //if cancel does not work, we cannot do anything about it here. Push reset button on Calliope should suffice
            statusDelegate?.dfuStateDidChange(to: .completed)
        }
        else {
        updateCallback("partial flashing starts sending new program to calliope")
        //start sending program part packages to calliope
        startPackageNumber = 0
        sendNextPackages()

        }
    }
    
    private func sendNextPackages() {
        updateCallback("send 4 packages beginning at \(startPackageNumber)")
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
        sendCurrentPackages()
        if currentDataToFlash.count < 4 {
            endTransmission() //we did not have a full package to flash any more
        }
        startPackageNumber = startPackageNumber.addingReportingOverflow(4).partialValue
        linesFlashed += 4
    }
    
    private func resendPackages() {
        fallbackToFullFlash()
        /*
         startPackageNumber -= 4
         updateCallback("Needs to resend package \(startPackageNumber)")
         //FIXME
         let resetPackageData = Data()
         send(command: .WRITE, value: resetPackageData)
         sendCurrentPackages()
         */
    }
    
    private func sendCurrentPackages() {
        updateCallback("sending \(currentDataToFlash.count) packages")
        for (index, package) in currentDataToFlash.enumerated() {
            let packageAddress = index == 1 ? currentSegmentAddress.bigEndianData : package.address.bigEndianData
            let packageNumber = Data([startPackageNumber + UInt8(index)])
            let writeData = packageAddress + packageNumber + package.data
            send(command: .WRITE, value: writeData)
        }
    }
    
    private func endTransmission() {
        isPartiallyFlashing = false
        shouldRebootOnDisconnect = false
        updateCallback("partial flashing done!")
        send(command: .TRANSMISSION_END)
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
        updateCallback("partial flash failed, resort to full flashing")
        do {
            try startFullFlashing()
        } catch {
            LogNotify.log("full flashing failed, cancel upload")
            _ = cancelUpload()
        }
    }
    
    //MARK: partial flashing callbacks to GUI
    
    private func updateCallback(_ logMessage: String) {
        logReceiver?.logWith(.info, message: logMessage)
        let progressPerCent = Int(ceil(Double(linesFlashed * 100) / Double(partialFlashData?.lineCount ?? Int.max)))
        LogNotify.log("partial flashing progress: \(progressPerCent)%")
        progressReceiver?.dfuProgressDidChange(for: 1, outOf: 1, to: progressPerCent, currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0)
        //Notify statusDelegate of completed Progress
        if progressPerCent == 100 {
            statusDelegate?.dfuStateDidChange(to: .completed)
        }
    }
    
    //MARK: dfu delegate
    
    override func dfuStateDidChange(to state: DFUState) {
        if state == .starting {
            rebootingIntoDFUMode = false
        }
        statusDelegate?.dfuStateDidChange(to: state)
    }
    
    
    override func dfuError(_ error: NordicDFU.DFUError, didOccurWithMessage message: String) {
        rebootingIntoDFUMode = false
        statusDelegate?.dfuError(error, didOccurWithMessage: message)
    }
    
    
}

//MARK: Calliope V1 and V2

class CalliopeV1AndV2: FlashableBLECalliope {
    
    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        return [.universal, .v2]
    }
    
    override var requiredServices: Set<CalliopeService> {
        return [.dfuControlService]
    }
    
    override var optionalServices: Set<CalliopeService> {
        return [.partialFlashing]
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
        
        let firmware = DFUFirmware(binFile:bin, datFile:dat, type: .application)
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
            shouldRebootOnDisconnect = false
        }
    }
    
    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        return [.universal, .v3]
    }
    
    override var requiredServices: Set<CalliopeService> {
        return [.secureDfuService]
    }
    
    override var optionalServices: Set<CalliopeService> {
        return [.partialFlashing]
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

        transferFirmware()
    }
    
    internal override func startPartialFlashing() {
        // TODO: Solve Partial Flashing Errors
        // Partial Flashing does not work entirely functional with the current Version of the Firmware. We therefor fallback to Full Flashing until this has been solved.
        // Partial Flashing starts, but the Calliope disconnects unexpectedly after around 6% have been transfered.
        do {
            shouldRebootOnDisconnect = false
            try startFullFlashing()
        } catch {
            LogNotify.log("Tried reverting to Full Flashing, but failed")
        }
    }
}



//MARK: constants for partial flasing
private extension UInt8 {
    //commands
    static let REBOOT = UInt8(0xFF)
    static let STATUS = UInt8(0xEE)
    static let REGION = UInt8(0)
    static let WRITE = UInt8(1)
    static let TRANSMISSION_END = UInt8(2)

    //REGION parameters
    static let EMBEDDED_REGION = UInt8(0)
    static let DAL_REGION = UInt8(1)
    static let PROGRAM_REGION = UInt8(2)

    //STATUS and REBOOT parameters
    static let MODE_APPLICATION = UInt8(1)
    static let MODE_BLE = UInt8(0)

    //WRITE response values
    static let WRITE_FAIL = UInt8(0xAA)
    static let WRITE_SUCCESS = UInt8(0xFF)
}
