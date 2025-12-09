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
    private var isPartiallyFlashing = false

    internal(set) var file: Hex?

    weak internal(set) var progressReceiver: DFUProgressDelegate?
    weak internal(set) var statusDelegate: DFUServiceDelegate?
    weak internal(set) var logReceiver: LoggerDelegate?

    override func notify(aboutState newState: DiscoveredDevice.CalliopeBLEDeviceState) {
        LogNotify.log("Received notification about state change to \(newState)")
        if newState == .usageReady && rebootingForPartialFlashing {
            updateQueue.async {
                self.startPartialFlashing()
            }
        } else if newState == .discovered && isPartiallyFlashing {
            LogNotify.log("Lost connection to Calliope mini during flashing process")
            // Abort if in discovered state but not in DfuProcess, however if is partial flashing
            DispatchQueue.main.async {
                self.statusDelegate?.dfuError(.deviceDisconnected, didOccurWithMessage: "connection to calliope lost")
            }
        }
    }

    public override func cancelUpload() -> Bool {
        cancel = true  //cancels partial flashing on next callback of calliope
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

        // Base class always uses full flashing.
        // Board-specific subclasses may override to enable partial flashing.
        self.file = file
        self.progressReceiver = progressReceiver
        self.statusDelegate = statusDelegate
        self.logReceiver = logReceiver

        try startFullFlashing()
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

    // Block/packet state for partial flashing (micro:bit firmware protocol)
    var currentBlockPackets: [[UInt8]] = [] // Each is a 20-byte array, not used directly but kept for clarity
    var currentBlockOffset: UInt32 = 0
    var currentBlockPacketNumber: UInt8 = 0
    var nextBlockIndex: Int = 0 // Track which block to send next
    var partialFlashBlocks: [Data] = [] // Each Data is up to 64 bytes (4*16)
    var resendCurrentBlock: Bool = false

    override func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {
        guard characteristic == .partialFlashing else {
            super.handleValueUpdate(characteristic, value)
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
            updateCallback("Received cancel call")
            return
        }

        if value[0] == .STATUS {
            //requested the mode of the calliope
            receivedStatus(value[2] == .MODE_APPLICATION)
            return
        }

        if value[0] == .REGION && value[1] == .DAL_REGION {
            //requested dal hash and position
            dalHash = value[10..<18]
            receivedDalHash()
            return
        }

        if value[0] == .REGION && value[1] == .PROGRAM_REGION {
            currentProgramHash = value[10..<18]
            receivedProgramHash()
            return
        }

        if value[0] == .REGION && value[1] == .EMBEDDED_REGION {
            receivedEmbedHash()
            return
        }

        // Handle micro:bit firmware protocol WRITE response
        if value[0] == .WRITE {
            if value.count < 2 {
                fallbackToFullFlash()
                return
            }
            if value[1] == .WRITE_FAIL {
                updateCallback("Partial flash: block failed, resending block")
                LogNotify.log("Partial flash WRITE_FAIL received, resending block \(nextBlockIndex)")
                resendCurrentBlock = true
                sendNextBlock()
            } else if value[1] == .WRITE_SUCCESS {
                updateCallback("Partial flash: block succeeded, sending next block")
                LogNotify.log("Partial flash WRITE_SUCCESS received, moving to block \(nextBlockIndex + 1)")
                nextBlockIndex += 1
                sendNextBlock()
            } else {
                fallbackToFullFlash()
            }
            return
        }
    }


    func startPartialFlashing() {
        rebootingForPartialFlashing = false

        updateCallback("Start partial flashing")
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

        // Reset partial flashing block state
        currentBlockPackets = []
        currentBlockOffset = 0
        currentBlockPacketNumber = 0
        nextBlockIndex = 0
        partialFlashBlocks = []
        resendCurrentBlock = false

        hexFileHash = partialFlashingInfo.fileHash
        hexProgramHash = partialFlashingInfo.programHash
        partialFlashData = partialFlashingInfo.partialFlashData

        // Prepare flash blocks for transmission (64 bytes per block)
        if let flashData = partialFlashData {
            var contiguous = Data()
            var pfData = flashData
            while let next = pfData.next() {
                contiguous.append(next.data)
            }
            LogNotify.log("PartialFlashData diff bytes: \(contiguous.count)")
            if contiguous.count > 0 {
                let totalBlocks = (contiguous.count + 63) / 64
                partialFlashBlocks = (0..<totalBlocks).map { i in
                    let startIdx = i * 64
                    let endIdx = min(contiguous.count, startIdx + 64)
                    return contiguous.subdata(in: startIdx..<endIdx)
                }
            } else {
                partialFlashBlocks = []
            }
        } else {
            partialFlashBlocks = []
        }
        LogNotify.log("Partial flash blocks to send: \(partialFlashBlocks.count)")
        nextBlockIndex = 0
        resendCurrentBlock = false

        // request dal hash
        send(command: .REGION, value: Data([.DAL_REGION]))
    }

    private func receivedDalHash() {
        updateCallback("Received dal hash")
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
        updateCallback("Received program hash")
        if currentProgramHash == hexProgramHash {
            linesFlashed = partialFlashData?.lineCount ?? Int.max  //set progress to 100%
            updateCallback("No changes to upload")
            let _ = cancelUpload()  //if cancel does not work, we cannot do anything about it here. Push reset button on Calliope should suffice
            statusDelegate?.dfuStateDidChange(to: .completed)
        } else {
            updateCallback("Partial flashing starts sending new program to Calliope mini")
            //start sending blocks of 4 packets to calliope
            startPackageNumber = 0
            linesFlashed = 0
            currentBlockPacketNumber = 0
            nextBlockIndex = 0
            sendNextBlock()
        }
    }

    /// Send the next 4-packet block according to micro:bit firmware protocol:
    /// Each block consists of 4 packets; each packet is 20 bytes:
    /// 1 byte: WRITE command (FLASH_DATA)
    /// 2 bytes: offset (high, low)
    /// 1 byte: packet number (incrementing per packet)
    /// 16 bytes: data
    ///
    /// After sending 4 packets, wait for notification {WRITE, 0xFF} before sending next block,
    /// or {WRITE, 0xAA} to resend the current block.
    private func sendNextBlock() {
        guard nextBlockIndex < partialFlashBlocks.count else {
            // All blocks sent, send END_OF_TRANSMISSION
            LogNotify.log("All partial flash blocks sent, transmission complete.")
            updateCallback("All blocks sent, sending transmission end")
            send(command: .TRANSMISSION_END)
            endTransmission()
            return
        }
        let blockData = partialFlashBlocks[nextBlockIndex]
        let blockOffset = UInt32(nextBlockIndex) * 64
        // Send 4 packets per block
        for packetNum in 0..<4 {
            var packet = [UInt8](repeating: 0, count: 20)
            packet[0] = .WRITE // FLASH_DATA
            // Offset is split into 2 bytes: high byte, low byte (big endian)
            packet[1] = UInt8((blockOffset >> 8) & 0xFF) // Offset high byte
            packet[2] = UInt8(blockOffset & 0xFF)        // Offset low byte
            packet[3] = currentBlockPacketNumber &+ UInt8(packetNum) // Incrementing packet number
            let dataStart = packetNum * 16
            let dataEnd = min(blockData.count, dataStart + 16)
            if dataStart < dataEnd {
                let bytesToCopy = dataEnd - dataStart
                let dataSlice = blockData.subdata(in: dataStart..<dataEnd)
                dataSlice.copyBytes(to: &packet[4], count: bytesToCopy)
            }
            LogNotify.log("Sending block \(nextBlockIndex), packet \(packetNum), offset: 0x\(String(format: "%04X", blockOffset)), data: \(Data(packet).hexEncodedString())")
            do {
                try writeWithoutResponse(Data(packet), for: .partialFlashing)
            } catch {
                LogNotify.log("BLE write error, falling back to full flash: \(error)")
                fallbackToFullFlash()
                return
            }
        }
        // Update state for next block
        currentBlockOffset = blockOffset
        currentBlockPacketNumber = currentBlockPacketNumber &+ 4
        resendCurrentBlock = false
    }

    private func resendPackages() {
        // Deprecated: replaced by resendCurrentBlock logic and sendNextBlock
        fallbackToFullFlash()
    }

    private func sendNextPackages() {
        sendNextBlock()
    }

    private func endTransmission() {
        isPartiallyFlashing = false
        shouldRebootOnDisconnect = false
        updateCallback("Partial flashing done!")
        send(command: .TRANSMISSION_END)
    }


    //MARK: partial flashing utility functions

    private func send(command: UInt8, value: Data = Data()) {
        do {
            try writeWithoutResponse(Data([command]) + value, for: .partialFlashing)
        } catch {
            LogNotify.log("BLE write error sending command 0x\(String(format: "%02X", command)), falling back to full flash: \(error)")
            fallbackToFullFlash()
        }
    }


    private func fallbackToFullFlash() {
        if isPartiallyFlashing {
            isPartiallyFlashing = false
            LogNotify.log("Partial flash failed, resort to full flashing")
            updateCallback("Partial flash failed, resorting to full flashing")
            do {
                try startFullFlashing()
            } catch {
                LogNotify.log("Full flashing failed, cancel upload")
                _ = cancelUpload()
            }
        }
    }

    //MARK: partial flashing callbacks to GUI

    private func updateCallback(_ logMessage: String) {
        logReceiver?.logWith(.info, message: logMessage)

        // Report progress only if meaningful
        let totalLines = partialFlashData?.lineCount ?? Int.max
        let progressPerCent = Int(floor(Double(linesFlashed * 100) / Double(totalLines)))

        // Only update progress if above 0% to avoid flooding logs with initial zeros
        if progressPerCent > 0 || logMessage.contains("done") || logMessage.contains("failed") || logMessage.contains("No changes") {
            LogNotify.log("Partial flashing progress: \(progressPerCent)%")
            progressReceiver?.dfuProgressDidChange(for: 1, outOf: 1, to: progressPerCent, currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0)
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


    // MARK: - BLE Peripheral Delegate forwarding for write without response readiness
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        //super.peripheralIsReady(toSendWriteWithoutResponse: peripheral) // Removed call to super as requested
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            // Continue sending queued partial flash packages if any
            self.sendAsManyPackagesAsPossible()
        }
    }

    // The old sendAsManyPackagesAsPossible is not used anymore for micro:bit protocol, but we keep it empty to avoid issues.
    private func sendAsManyPackagesAsPossible() {
        // No-op for new micro:bit partial flashing implementation
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
            shouldRebootOnDisconnect = false
        }
    }

    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        [.universal, .v3]
    }

    override var requiredServices: Set<CalliopeService> {
        [.secureDfuService]
    }

    // Override upload to enable partial flashing for v3 if available.
    override public func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        self.file = file
        self.progressReceiver = progressReceiver
        self.statusDelegate = statusDelegate
        self.logReceiver = logReceiver

        LogNotify.log("Partial flashing service available: \(discoveredOptionalServices.contains(.partialFlashing))")
        if discoveredOptionalServices.contains(.partialFlashing) {
            startPartialFlashing()
        } else {
            try startFullFlashing()
        }
    }

    // TODO: v3 defaults to full flash
    //  - dat [makecode: 56 bytes, open-roberta: 56 bytes]
    //  - bin [makecode: 183152 bytes], [open-roberta: 314117 bytes]
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

}


//MARK: constants for partial flasing
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

