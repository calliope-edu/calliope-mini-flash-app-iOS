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

    private var bin: Data?
    private var dat: Data?

    private var progressReceiver: DFUProgressDelegate?
    private var statusDelegate: DFUServiceDelegate?
    private var logReceiver: LoggerDelegate?

    override func handleStateUpdate() {
        if state == .discovered && rebootingForFirmwareUpgrade {
            rebootingForFirmwareUpgrade = false
            transferFirmware()
        } else if state == .usageReady && rebootingForPartialFlashing {
            rebootingForPartialFlashing = false
            startPartialFlashing()
        }
    }

    public func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {

        bin = file.bin
        dat = HexFile.dat(file.bin)

        self.progressReceiver = progressReceiver
        self.statusDelegate = statusDelegate
        self.logReceiver = logReceiver

        //TODO: attempt partial flashing first
        // Android implementation: https://github.com/microbit-sam/microbit-android/blob/partial-flash/app/src/main/java/com/samsung/microbit/service/PartialFlashService.java
        // Explanation: https://lancaster-university.github.io/microbit-docs/ble/partial-flashing-service/

        //try rebootForPartialFlashing()

        try rebootForFullFlashing()
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
        guard let bin = bin, let dat = dat, let firmware = DFUFirmware(binFile:bin, datFile:dat, type: .application) else {
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

    private func rebootForPartialFlashing() throws {
        state = .willReset
        rebootingForPartialFlashing = true
        try writeWithoutResponse(Data([0xFF, 0x00]), for: .partialFlashing)
    }

    private func startPartialFlashing() {
        

        print("partial flashing should start now")

    }
}
