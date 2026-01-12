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
    
    // Tracks whether DFU has completed successfully and we're waiting for reconnect
    private var dfuCompletedAwaitingReconnect = false
    
    // Callback to request disconnect from CalliopeDiscovery
    var requestDisconnectCallback: (() -> Void)?
    
    internal private(set) var file: Hex?

    weak internal private(set) var progressReceiver: DFUProgressDelegate?
    weak internal private(set) var statusDelegate: DFUServiceDelegate?
    weak internal private(set) var logReceiver: LoggerDelegate?

    override func notify(aboutState newState: DiscoveredDevice.CalliopeBLEDeviceState) {
        LogNotify.log("Received notification about state change to \(newState)")
        
        switch newState {
        case .usageReady:
            if rebootingForPartialFlashing {
                LogNotify.log("[PartialFlash] Device reconnected after reboot, resuming partial flashing...")
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
                DispatchQueue.main.async {
                    self.statusDelegate?.dfuError(.deviceDisconnected, didOccurWithMessage: "connection to calliope lost")
                }
            } else if rebootingForPartialFlashing {
                LogNotify.log("[PartialFlash] Device disconnected after reboot command, waiting for reconnection...")
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

        // Prüfe ob Partial Flashing verfügbar ist und sinnvoll (< 700 Zeilen zu ändern)
        if discoveredOptionalServices.contains(.partialFlashing),
           let partialInfo = file.partialFlashingInfo {
            let lineCount = partialInfo.partialFlashData.lineCount
            LogNotify.log("Partial flashing: \(lineCount) lines to change")

            if lineCount < 700 {
                LogNotify.log("Using partial flashing (< 700 lines)")
                startPartialFlashing()
            } else {
                LogNotify.log("Skipping partial flashing (>= 700 lines), using full flash instead")
                shouldRebootOnDisconnect = true
                try startFullFlashing()
            }
        } else {
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
    
    // MARK: Enhanced partial flashing state (flow control, timeout, retry)
    private let partialFlashingStateLock = NSLock()
    private var isPartialFlashingActive = false
    private var currentBlockRetryCount = 0
    private let maxBlockRetries = 3
    private var blockTransmissionTimer: Timer?
    private let blockTimeout: TimeInterval = 5.0
    private var partialFlashStartTime: Date?
    private var totalPacketsToSend: Int = 0
    private var currentBlockStartTime: Date?
    
    // Flow control for iOS 11+
    private var packetsToSend: [(index: Int, package: (address: UInt16, data: Data))] = []
    private var currentBlockSendIndex = 0
    private var flowControlRetryCount = 0
    private let maxFlowControlRetries = 100  // Max 1 second total wait (10ms * 100)

    override func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {
        guard characteristic == .partialFlashing else {
            super.handleValueUpdate(characteristic, value)
            return
        }
        //dispatch from ble queue to update queue to avoid deadlock
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Thread safety: only process notifications when actively flashing
            self.partialFlashingStateLock.lock()
            let isActive = self.isPartialFlashingActive
            self.partialFlashingStateLock.unlock()
            
            guard isActive else {
                self.debugLog("Ignoring notification - not actively flashing")
                return
            }
            
            self.handlePartialValueNotification(value)
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
            // Cancel timeout timer on any response
            blockTransmissionTimer?.invalidate()
            blockTransmissionTimer = nil
            
            let blockDuration = currentBlockStartTime.map { Date().timeIntervalSince($0) } ?? 0
            updateCallback("write status: \(Data([value[1]]).hexEncodedString()) (block took \(String(format: "%.3f", blockDuration))s)")
            
            if value[1] == .WRITE_FAIL {
                LogNotify.log("Received WRITE_FAIL (0xAA), attempting retry")
                resendPackages()
            } else if value[1] == .WRITE_SUCCESS {
                debugLog("Received WRITE_SUCCESS (0xFF), proceeding to next block")
                
                // Update counters after successful transmission
                startPackageNumber = startPackageNumber.addingReportingOverflow(UInt8(currentDataToFlash.count)).partialValue
                linesFlashed += currentDataToFlash.count
                debugLog("Transmitted \(linesFlashed) lines")
                
                // Reset retry counter on success
                currentBlockRetryCount = 0
                flowControlRetryCount = 0
                
                // This should only be called for full 4-packet blocks
                // Incomplete blocks are handled immediately in sendNextPacketInBlock()
                debugLog("Full block (\(currentDataToFlash.count) packets) ACK received, sending next block")
                sendNextPackages()
            } else {
                //we do not understand the response
                LogNotify.log("Unknown write response: \(value[1]), falling back to full flash")
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
        
        // Initialize enhanced partial flashing state
        partialFlashingStateLock.lock()
        isPartialFlashingActive = true
        partialFlashingStateLock.unlock()
        
        currentBlockRetryCount = 0
        flowControlRetryCount = 0
        partialFlashStartTime = Date()
        totalPacketsToSend = partialFlashingInfo.partialFlashData.lineCount
        blockTransmissionTimer?.invalidate()
        blockTransmissionTimer = nil
        
        debugLog("Starting partial flashing: \(totalPacketsToSend) packets to send")

        hexFileHash = partialFlashingInfo.fileHash
        hexProgramHash = partialFlashingInfo.programHash
        partialFlashData = partialFlashingInfo.partialFlashData

        // Skip DAL hash check before reboot - we'll verify it after device is in BLE mode
        // This saves ~160ms per flash operation
        LogNotify.log("[PartialFlash] Skipping initial DAL verification, requesting device status...")
        send(command: .STATUS)
    }

    private func receivedDalHash() {
        updateCallback("Received dal hash \(dalHash.hexEncodedString()), hash in hex file is \(hexFileHash.hexEncodedString())")
        LogNotify.log("[PartialFlash] DAL hash verified: \(dalHash == hexFileHash ? "✓ match" : "✗ mismatch")")
        guard dalHash == hexFileHash else {
            LogNotify.log("[PartialFlash] DAL hash mismatch - falling back to full flash")
            fallbackToFullFlash()
            return
        }

        // Device is in BLE mode and DAL verified, continue with embedded region
        send(command: .REGION, value: Data([.EMBEDDED_REGION]))
    }

    func receivedStatus(_ needsRebootIntoBLEOnlyMode: Bool) {
        LogNotify.log("[PartialFlash] Received status: needsReboot=\(needsRebootIntoBLEOnlyMode)")
        updateCallback("Received mode of Calliope mini, needs reboot: \(needsRebootIntoBLEOnlyMode)")
        if needsRebootIntoBLEOnlyMode {
            shouldRebootOnDisconnect = true
            rebootingForPartialFlashing = true
            //calliope is in application state and needs to be rebooted
            LogNotify.log("[PartialFlash] Sending reboot command to enter BLE mode...")
            send(command: .REBOOT, value: Data([.MODE_BLE]))
            
            // Immediately disconnect to avoid waiting for iOS to detect timeout (saves ~4s)
            LogNotify.log("[PartialFlash] Triggering disconnect to speed up reconnection...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.requestDisconnectCallback?()
            }
        } else {
            //calliope is already in bluetooth state
            LogNotify.log("[PartialFlash] Device already in BLE mode, verifying DAL hash...")
            isPartiallyFlashing = true
            // Now request DAL hash to verify firmware compatibility
            send(command: .REGION, value: Data([.DAL_REGION]))
        }
    }

    private func receivedEmbedHash() {
        LogNotify.log("[PartialFlash] Received embedded region hash")
        updateCallback("Received embed hash")
        // request program hash
        send(command: .REGION, value: Data([.PROGRAM_REGION]))
    }

    private func receivedProgramHash() {
        LogNotify.log("[PartialFlash] Received program hash - current: \(currentProgramHash.hexEncodedString()), target: \(hexProgramHash.hexEncodedString())")
        updateCallback("Received program hash \(hexProgramHash.hexEncodedString())")
        if currentProgramHash == hexProgramHash {
            LogNotify.log("[PartialFlash] Program unchanged - rebooting to application mode")
            linesFlashed = partialFlashData?.lineCount ?? Int.max  //set progress to 100%
            updateCallback("No changes to upload")
            
            // Clear flashing flag BEFORE reboot to prevent disconnect error
            partialFlashingStateLock.lock()
            isPartialFlashingActive = false
            isPartiallyFlashing = false
            partialFlashingStateLock.unlock()
            
            // Reboot device back to application mode since we're done
            send(command: .REBOOT, value: Data([.MODE_APPLICATION]))
            
            // Wait briefly for reboot command, then complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                let _ = self?.cancelUpload()
                self?.statusDelegate?.dfuStateDidChange(to: .completed)
            }
        } else {
            LogNotify.log("[PartialFlash] ⚡ Starting data transmission now (setup complete)")
            updateCallback("Partial flashing starts sending new program to Calliope mini")
            startPackageNumber = 0
            sendNextPackages()
        }
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
        
        // Check if we're done - no more data to send
        if currentDataToFlash.count == 0 {
            debugLog("No more data to send, ending transmission")
            endTransmission()
            return
        }
        
        // Pad incomplete blocks with 0xFF (like Android does)
        // Device firmware expects blocks of 4 packets
        if currentDataToFlash.count < 4 {
            let paddingCount = 4 - currentDataToFlash.count
            debugLog("Padding last block with \(paddingCount) packets of 0xFF")
            let paddingData = Data(repeating: 0xFF, count: 16)
            for _ in 0..<paddingCount {
                // Use address 0x0000 for padding packets (they'll be ignored by device)
                currentDataToFlash.append((address: 0x0000, data: paddingData))
            }
        }
        
        // Start timeout timer for this block
        currentBlockStartTime = Date()
        blockTransmissionTimer?.invalidate()
        blockTransmissionTimer = Timer.scheduledTimer(withTimeInterval: blockTimeout, repeats: false) { [weak self] _ in
            self?.handleBlockTimeout()
        }
        
        sendCurrentPackagesWithFlowControl()
    }

    private func resendPackages() {
        // Prevent duplicate retry triggers
        partialFlashingStateLock.lock()
        guard isPartialFlashingActive else {
            partialFlashingStateLock.unlock()
            return
        }
        partialFlashingStateLock.unlock()
        
        currentBlockRetryCount += 1
        
        if currentBlockRetryCount > maxBlockRetries {
            LogNotify.log("Max retries (\(maxBlockRetries)) exceeded for block, falling back to full flash")
            fallbackToFullFlash()
            return
        }
        
        LogNotify.log("Retrying block transmission (attempt \(currentBlockRetryCount)/\(maxBlockRetries))")
        updateCallback("Retry #\(currentBlockRetryCount): Resending \(currentDataToFlash.count) packets")
        
        // Reset packet send index and retry same block
        currentBlockSendIndex = 0
        flowControlRetryCount = 0
        
        // Restart timeout timer
        currentBlockStartTime = Date()
        blockTransmissionTimer?.invalidate()
        blockTransmissionTimer = Timer.scheduledTimer(withTimeInterval: blockTimeout, repeats: false) { [weak self] _ in
            self?.handleBlockTimeout()
        }
        
        // Add small delay before retry (100ms) to let device recover
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.sendCurrentPackagesWithFlowControl()
        }
    }
    
    private func handleBlockTimeout() {
        LogNotify.log("Block transmission timeout (\(blockTimeout)s) - no response from device")
        updateCallback("Timeout waiting for device response")
        
        // Treat timeout as failure and retry
        resendPackages()
    }

    private func sendCurrentPackagesWithFlowControl() {
        // Check buffer before starting new block (iOS 11+)
        if #available(iOS 11.0, *) {
            if !peripheral.canSendWriteWithoutResponse {
                // Buffer full, retry in 10ms
                flowControlRetryCount += 1
                
                if flowControlRetryCount >= maxFlowControlRetries {
                    LogNotify.log("Flow control timeout - buffer stayed full for 1 second before block start")
                    fallbackToFullFlash()
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                    self?.sendCurrentPackagesWithFlowControl()
                }
                return
            }
        }
        
        updateCallback("Sending \(currentDataToFlash.count) packages, beginning at \(startPackageNumber)")
        
        // Prepare packets to send
        packetsToSend = currentDataToFlash.enumerated().map { ($0.offset, $0.element) }
        currentBlockSendIndex = 0
        flowControlRetryCount = 0
        
        // Start sending (all 4 packets immediately)
        sendNextPacketInBlock()
    }
    
    private func sendNextPacketInBlock() {
        // Check if we've sent all packets in this block
        guard currentBlockSendIndex < packetsToSend.count else {
            // All 4 packets sent (including padding if needed) - wait for device ACK
            debugLog("All \(packetsToSend.count) packets sent, waiting for device response")
            return
        }
        
        let (index, package) = packetsToSend[currentBlockSendIndex]
        
        // Check buffer availability with flow control (iOS 11+)
        if #available(iOS 11.0, *) {
            if index > 0 && !peripheral.canSendWriteWithoutResponse {
                // Buffer full, retry in 10ms
                flowControlRetryCount += 1
                
                if flowControlRetryCount >= maxFlowControlRetries {
                    LogNotify.log("Flow control timeout - buffer stayed full for 1 second while sending packet \(index)")
                    fallbackToFullFlash()
                    return
                }
                
                debugLog("Buffer full for packet \(index), retrying in 10ms (retry \(flowControlRetryCount)/\(maxFlowControlRetries))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                    self?.sendNextPacketInBlock()
                }
                return
            }
        }
        
        // Send packet with flow control
        let packageAddress = currentBlockSendIndex == 1 ? currentSegmentAddress.bigEndianData : package.address.bigEndianData
        let currentPacketNumber = startPackageNumber.addingReportingOverflow(UInt8(currentBlockSendIndex)).partialValue
        let packageNumber = Data([currentPacketNumber])
        let writeData = packageAddress + packageNumber + package.data
        
        debugLog("Sending packet \(currentPacketNumber) (\(currentBlockSendIndex + 1)/\(packetsToSend.count))")
        send(command: .WRITE, value: writeData)
        
        // Move to next packet
        currentBlockSendIndex += 1
        
        // Continue sending next packet immediately (flow control will throttle if needed)
        sendNextPacketInBlock()
    }

    private func endTransmission() {
        shouldRebootOnDisconnect = false
        blockTransmissionTimer?.invalidate()
        blockTransmissionTimer = nil
        
        let duration = partialFlashStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let avgSpeed = duration > 0 ? Double(linesFlashed * 16) / duration : 0
        
        updateCallback("Partial flashing done in \(String(format: "%.2f", duration))s (\(Int(avgSpeed)) bytes/s)")
        debugLog("Transmission complete: \(linesFlashed) packets in \(String(format: "%.2f", duration))s")
        
        // Send TRANSMISSION_END before cleaning up state
        debugLog("Sending TRANSMISSION_END (0x02) command")
        updateCallback("Sending end of transmission command...")
        send(command: .TRANSMISSION_END)
        
        // Now clean up state AFTER sending the command
        partialFlashingStateLock.lock()
        isPartialFlashingActive = false
        isPartiallyFlashing = false
        partialFlashingStateLock.unlock()
        
        // Per BLE partial flash protocol, device firmware should:
        // 1. Process TRANSMISSION_END command
        // 2. Remove embedded source magic
        // 3. Automatically disconnect and reboot into application mode
        // Give device time to process and initiate reboot before signaling completion.
        // Android implementation waits 100ms then explicitly disconnects.
        updateCallback("Waiting for device to reboot into application mode...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.statusDelegate?.dfuStateDidChange(to: .completed)
        }
    }


    //MARK: partial flashing utility functions

    private func send(command: UInt8, value: Data = Data()) {
        let commandData = Data([command]) + value
        debugLog("Sending command: 0x\(String(format: "%02X", command)) with \(value.count) bytes of data")
        do {
            try writeWithoutResponse(commandData, for: .partialFlashing)
            debugLog("Command 0x\(String(format: "%02X", command)) sent successfully")
        } catch {
            LogNotify.log("Write failed for command 0x\(String(format: "%02X", command)): \(error.localizedDescription)")
            fallbackToFullFlash()
        }
    }

    private func fallbackToFullFlash() {
        // Clean up partial flashing state
        partialFlashingStateLock.lock()
        isPartialFlashingActive = false
        isPartiallyFlashing = false
        partialFlashingStateLock.unlock()
        
        blockTransmissionTimer?.invalidate()
        blockTransmissionTimer = nil
        
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
        
        let total = max(partialFlashData?.lineCount ?? 1, 1)  // Avoid division by zero
        let progressPercent = Int(floor(Double(linesFlashed * 100) / Double(total)))
        
        // Calculate speed if we have timing data
        var avgSpeed: Double = 0
        var currentSpeed: Double = 0
        
        if let startTime = partialFlashStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 {
                avgSpeed = Double(linesFlashed * 16) / elapsed  // bytes per second
                currentSpeed = avgSpeed  // For now, use same value
            }
        }
        
        LogNotify.log("Partial flashing: \(progressPercent)% (\(linesFlashed)/\(total) packets, \(Int(avgSpeed)) bytes/s)")
        
        progressReceiver?.dfuProgressDidChange(
            for: 1,
            outOf: 1,
            to: progressPercent,
            currentSpeedBytesPerSecond: currentSpeed,
            avgSpeedBytesPerSecond: avgSpeed
        )
    }
    
    // MARK: Debug logging
    private func debugLog(_ message: String) {
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        LogNotify.log("[PF-\(String(format: "%.3f", timestamp))] \(message)")
        #endif
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
            if discoveredOptionalServices.contains(.partialFlashing),
               let pfCharacteristic = getCBCharacteristic(.partialFlashing) {
                peripheral.setNotifyValue(true, for: pfCharacteristic)
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
}

// MARK: - Partial Flashing V3 Implementation Notes
//
// CalliopeV3 now uses the standard partial flashing implementation from FlashableBLECalliope.
// Key requirements:
// 1. Must use 4-packet blocks with device acknowledgment (WRITE_SUCCESS) between blocks
// 2. Must respect iOS CoreBluetooth flow control (canSendWriteWithoutResponse on iOS 11+)
// 3. Device firmware protocol:
//    - Send: WRITE command + 4 packets (address + packet# + 16 bytes data)
//    - Wait: Device notification with WRITE_SUCCESS (0xFF) or WRITE_FAIL (0xAA)
//    - Retry: On WRITE_FAIL, resend same 4 packets
//    - End: Send TRANSMISSION_END (0x02) after last packet
//
// See micro:bit Android implementation for reference:
// https://github.com/microbit-foundation/microbit-android

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
