//
//  DFUCalliope.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import UIKit
import iOSDFULibrary

class FlashableCalliope: CalliopeBLEDevice {

    // MARK: common

	override var requiredServices: Set<CalliopeService> {
		return [.dfu]
	}

    override var optionalServices: Set<CalliopeService> {
        return [.partialFlashing]
    }

	private var rebootingForFirmwareUpgrade = false
    private var rebootingForPartialFlashing = false

    private var file: Hex?

    private var progressReceiver: DFUProgressDelegate?
    private var statusDelegate: DFUServiceDelegate?
    private var logReceiver: LoggerDelegate?

    override func handleStateUpdate() {
        if state == .discovered && rebootingForFirmwareUpgrade {
            rebootingForFirmwareUpgrade = false
            transferFirmware()
        } else if state == .usageReady && rebootingForPartialFlashing {
            rebootingForPartialFlashing = false
            updateQueue.async {
                self.startPartialFlashing()
            }
        }
    }

    public func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil, partialFlashing: Bool = true) throws {

        self.file = file

        self.progressReceiver = progressReceiver
        self.statusDelegate = statusDelegate
        self.logReceiver = logReceiver

        //TODO: attempt partial flashing first
        // Android implementation: https://github.com/microbit-sam/microbit-android/blob/partial-flash/app/src/main/java/com/samsung/microbit/service/PartialFlashService.java
        // Explanation: https://lancaster-university.github.io/microbit-docs/ble/partial-flashing-service/
        // the explanation is outdated though.

        if (partialFlashing) {
            try startPartialFlashing()
        }
        else {
            //comment out this as soon as partial flashing works
            try startFullFlashing()
        }
	}

    public func cancelUpload() -> Bool {
        cancel = true //cancels partial flashing on next callback of calliope
        let success = uploader?.abort() //cancels full flashing
        if success ?? false {
            uploader = nil
        }
        return success ?? false
    }

    // MARK: full flashing

    private var initiator: DFUServiceInitiator? = nil
    private var uploader: DFUServiceController? = nil

    private func startFullFlashing() throws {

        guard let file = file else {
            return
        }

        let bin = file.bin
        let dat = HexFile.dat(bin)

        guard let firmware = DFUFirmware(binFile:bin, datFile:dat, type: .application) else {
            throw "Could not create firmware from given data"
        }

        try preparePairing()

        initiator = DFUServiceInitiator().with(firmware: firmware)
        initiator?.logger = logReceiver
        initiator?.delegate = statusDelegate
        initiator?.progressDelegate = progressReceiver

        try triggerDfuMode()
	}

    private func preparePairing() throws {
        //this apparently is necessary before DFU characteristic can be properly used
        //was like this in the old app version
        _ = try read(characteristic: .dfuControl)
    }

    private func triggerDfuMode() throws {
        let data = Data([0x01])
        rebootingForFirmwareUpgrade = true
        try write(data, for: .dfuControl)
    }

	private func transferFirmware() {

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
            receivedCalliopeMode(value[2] == .MODE_APPLICATION)
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

    private func startPartialFlashing() {

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


        updateCallback("start partial flashing")
        guard let file = file,
              let partialFlashingInfo = file.partialFlashingInfo,
              let partialFlashingCharacteristic = getCBCharacteristic(.partialFlashing) else {
            LogNotify.log("partialFlashing not found")
            fallbackToFullFlash()
            return
        }

        hexFileHash = partialFlashingInfo.fileHash
        hexProgramHash = partialFlashingInfo.programHash
        partialFlashData = partialFlashingInfo.partialFlashData

        peripheral.setNotifyValue(true, for: partialFlashingCharacteristic)

        send(command: .REGION, value: Data([.DAL_REGION]))
    }

    private func receivedDalHash() {
        updateCallback("received dal hash \(dalHash.hexEncodedString()), hash in hex file is \(hexFileHash.hexEncodedString())")
        guard dalHash == hexFileHash else {
            fallbackToFullFlash()
            return
        }
        //request mode (application running or BLE only)
        //send(command: .STATUS)
        send(command: .REGION, value: Data([.EMBEDDED_REGION]))
    }
    
    private func receivedProgramHash() {
        if currentProgramHash == hexProgramHash {
            cancelUpload()
            updateCallback("no changes to upload")
            statusDelegate?.dfuError(.remoteLegacyDFUSuccess, didOccurWithMessage: NSLocalizedString("No changes to upload", comment: ""))
            //progressReceiver?.dfuProgressDidChange(for: 1, outOf: 1, to: 100, currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0)
        }
        else {
            send(command: .STATUS)
        }
    }
    
    private func receivedEmbedHash() {
        send(command: .REGION, value: Data([.PROGRAM_REGION]))
    }

    private func receivedCalliopeMode(_ needsRebootIntoBLEOnlyMode: Bool) {
        updateCallback("received mode of calliope, needs reboot: \(needsRebootIntoBLEOnlyMode)")
        if (needsRebootIntoBLEOnlyMode) {
            rebootingForPartialFlashing = true
            //calliope is in application state and needs to be rebooted
            state = .willReset
            send(command: .REBOOT, value: Data([.MODE_BLE]))
        } else {
            //calliope is already in bluetooth state
            rebootForPartialFlashingDone()
        }
    }

    private func rebootForPartialFlashingDone() {
        updateCallback("reboot done if it was necessary, can now start sending new program to calliope")
        //start sending program part packages to calliope
        startPackageNumber = 0
        sendNextPackages()
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
        updateCallback("partial flashing done!")
        state = .willReset
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
        updateCallback("partial flash failed, resort to full flashing")
        do {
            try startFullFlashing()
        } catch {
            _ = cancelUpload()
        }
    }

    //MARK: partial flashing callbacks to GUI

    private func updateCallback(_ logMessage: String) {
        logReceiver?.logWith(.info, message: logMessage)
        let progressPerCent = Int(ceil(Double(linesFlashed * 100) / Double(partialFlashData?.lineCount ?? Int.max)))
        LogNotify.log("partial flashing progress: \(progressPerCent)%")
        progressReceiver?.dfuProgressDidChange(for: 1, outOf: 1, to: progressPerCent, currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0)
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
