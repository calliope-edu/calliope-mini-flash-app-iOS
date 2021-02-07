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

    var dalRegionStart = Data()
    var dalRegionEnd = Data()
    var dalHash = Data()

    var partialFlashData: PartialFlashData?

    override func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {

        guard characteristic == .partialFlashing else {
            return
        }

        if value[0] == 0xEE { //requested mode
            //we requested the state of the calliope and got a response
            if (value[2] == 0x01) {
                //calliope is in application state and needs to be rebooted
                state = .willReset
                do {
                    try writeWithoutResponse(Data([0xFF, 0x00]), for: .partialFlashing)
                } catch {
                    return //TODO start normal flashing
                }
            } else {
                //calliope is already in bluetooth state
                handleStateUpdate()
            }
        }

        if value[0] == 0x00 && value[1] == 0x01 { //requested dal hash
            dalRegionStart = value[2..<6]
            dalRegionEnd = value[6..<10]
            dalHash = value[10..<18]
            receivedDalHash()
        }
    }

    private func startPartialFlashing() throws {
        rebootingForPartialFlashing = true
        guard let partialFlashingCharacteristic = getCBCharacteristic(.partialFlashing) else {
            return //TODO start normal flasing
        }
        peripheral.setNotifyValue(true, for: partialFlashingCharacteristic)
        try writeWithoutResponse(Data([0xEE]), for: .partialFlashing) //request state
    }

    private func rebootForPartialFlashingDone() {
        do {
            try writeWithoutResponse(Data([0x00, 0x01]), for: .partialFlashing) //request dal hash
        } catch {
           return //TODO start normal flashing
        }
    }

    private func receivedDalHash() {

        guard let file = file else {
            return
        }

        guard let partialFlashingInfo = file.partialFlashingInfo, dalHash == partialFlashingInfo.fileHash else {
            return //TODO start normal flashing
        }

        self.partialFlashData = partialFlashingInfo.partialFlashData
        //TODO: start sending program part packages to calliope or request program hash first and compare
    }
}
