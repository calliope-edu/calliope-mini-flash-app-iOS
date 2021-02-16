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
            rebootForPartialFlashingDone()
        }
    }

    public func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {

        self.file = file

        self.progressReceiver = progressReceiver
        self.statusDelegate = statusDelegate
        self.logReceiver = logReceiver

        //TODO: attempt partial flashing first
        // Android implementation: https://github.com/microbit-sam/microbit-android/blob/partial-flash/app/src/main/java/com/samsung/microbit/service/PartialFlashService.java
        // Explanation: https://lancaster-university.github.io/microbit-docs/ble/partial-flashing-service/

        try startPartialFlashing()

        //try rebootForFullFlashing()
	}

    public func cancelUpload() -> Bool {
        let success = uploader?.abort()
        if success ?? false {
            uploader = nil
        }
        return success ?? false

        //TODO: abort also for partial flashing
    }

    // MARK: full flashing

    private var initiator: DFUServiceInitiator? = nil
    private var uploader: DFUServiceController? = nil

    private func rebootForFullFlashing() throws {

        guard let file = file else {
            return
        }

        let bin = file.bin
        let dat = HexFile.dat(bin)

        guard let firmware = DFUFirmware(binFile:bin, datFile:dat, type: .application) else {
            throw "Could not create firmware from given data"
        }

        triggerPairing()

        initiator = DFUServiceInitiator().with(firmware: firmware)
        initiator?.logger = logReceiver
        initiator?.delegate = statusDelegate
        initiator?.progressDelegate = progressReceiver

		let data = Data([0x01])
		rebootingForFirmwareUpgrade = true
		try write(data, for: .dfuControl)
	}

    private func triggerPairing() {
        //this apparently triggers pairing and is necessary before DFU characteristic can be properly used
        //was like this in the old app version
        _ = try? read(characteristic: .dfuControl)
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

    //data file and its properties
    var hexFileHash = Data()
    var hexProgramHash = Data()
    var partialFlashData: PartialFlashData?

    //current flash package data
    var startPackageNumber: UInt8 = 0
    var currentDataToFlash: [(address: Int, data: Data)] = []

    override func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {

        guard characteristic == .partialFlashing else {
            return
        }

        LogNotify.log("received notification from partial flashing service: \(value.hexEncodedString())")

        if value[0] == 0xEE {
            //requested the mode of the calliope
            receivedCalliopeMode(value[2] == 0x01)
            return
        }

        if value[0] == 0x00 && value[1] == 0x01 {
            //requested dal hash and position
            dalHash = value[10..<18]
            LogNotify.log("Dal region from \(value[2..<6].hexEncodedString()) to \(value[6..<10].hexEncodedString())")
            receivedDalHash()
            return
        }

        if value[0] == 0x01 {
            LogNotify.log("write status: \(Data([value[1]]).hexEncodedString())")
            if value[1] == 0xAA {
                resendPackage()
            } else {
                sendNextPackage()
            }
            return
        }
    }

    private func startPartialFlashing() throws {
        LogNotify.log("start partial flashing")
        guard let file = file,
              let partialFlashingInfo = file.partialFlashingInfo,
              let partialFlashingCharacteristic = getCBCharacteristic(.partialFlashing) else {
            fallbackToFullFlash()
            return
        }

        hexFileHash = partialFlashingInfo.fileHash
        hexProgramHash = partialFlashingInfo.programHash
        partialFlashData = partialFlashingInfo.partialFlashData

        peripheral.setNotifyValue(true, for: partialFlashingCharacteristic)

        try writeWithoutResponse(Data([0x00, 0x01]), for: .partialFlashing) //request dal hash
    }

    private func receivedDalHash() {
        LogNotify.log("received dal hash \(dalHash.hexEncodedString()), hash in hex file is \(hexFileHash.hexEncodedString())")
        guard dalHash == hexFileHash else {
            fallbackToFullFlash()
            return
        }

        do {
            try writeWithoutResponse(Data([0xEE]), for: .partialFlashing) //request mode (application running or BLE only)
        } catch {
            fallbackToFullFlash()
            return
        }
    }

    private func receivedCalliopeMode(_ needsRebootIntoBLEOnlyMode: Bool) {
        LogNotify.log("received mode of calliope, needs reboot: \(needsRebootIntoBLEOnlyMode)")
        if (needsRebootIntoBLEOnlyMode) {
            rebootingForPartialFlashing = true
            //calliope is in application state and needs to be rebooted
            state = .willReset
            do {
                try writeWithoutResponse(Data([0xFF, 0x00]), for: .partialFlashing)
            } catch {
                fallbackToFullFlash()
                return
            }
        } else {
            //calliope is already in bluetooth state
            rebootForPartialFlashingDone()
        }
    }

    private func rebootForPartialFlashingDone() {
        LogNotify.log("reboot done if it was necessary, can now start sending new program to calliope")
        //start sending program part packages to calliope
        startPackageNumber = 1
        sendNextPackage()
    }

    private func sendNextPackage() {
        LogNotify.log("send 4 packages beginning at \(startPackageNumber)")
        guard var partialFlashData = partialFlashData else {
            fallbackToFullFlash()
            return
        }
        currentDataToFlash = []
        for _ in 0..<4 {
            guard let nextPackage = partialFlashData.next() else {
                break
            }
            currentDataToFlash.append(nextPackage)
        }
        sendPackage()
        if currentDataToFlash.count < 4 {
            endTransmission() //we did not have a full package to flash any more
        }
        startPackageNumber += 4
    }

    private func resendPackage() {
        startPackageNumber -= 4
        LogNotify.log("Needs to resend package \(startPackageNumber)")
        do {
            try writeWithoutResponse(("AAAAAAAAAAAAAAAA".toData(using: .hex) ?? Data())
                                        + ("1234".toData(using: .hex) ?? Data())
                                        + Data([startPackageNumber]),
                                     for: .partialFlashing)
        } catch {
            fallbackToFullFlash()
            return
        }
        sendPackage()
    }

    private func sendPackage() {
        LogNotify.log("sending \(currentDataToFlash.count) packages")
        do {
            for (index, package) in currentDataToFlash.enumerated() {
                let writeCommand = Data([0x01])
                let packageNumber = Data([(startPackageNumber + UInt8(index))])
                let writeData = writeCommand + package.address + packageNumber + package.data
                try writeWithoutResponse(writeData, for: .partialFlashing)
            }
        } catch {
            fallbackToFullFlash()
            return
        }
    }

    private func endTransmission() {
        LogNotify.log("partial flashing done!")
        do {
            try writeWithoutResponse(Data([0x02]), for: .partialFlashing)
        } catch {
            fallbackToFullFlash()
            return
        }
    }


    private func fallbackToFullFlash() {
        LogNotify.log("partial flash failed, resort to full flashing")
        //TODO: start full flash
    }
}
