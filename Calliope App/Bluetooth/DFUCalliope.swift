//
//  DFUCalliope.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import UIKit
import iOSDFULibrary

class DFUCalliope: CalliopeBLEDevice {

	override var requiredServices: Set<CalliopeService> {
		return [.dfu]
	}

	private var rebootingForFirmwareUpgrade = false
	private var initiator: DFUServiceInitiator? = nil
	private var uploader: DFUServiceController? = nil

	override func handleStateUpdate() {
		if state == .discovered && rebootingForFirmwareUpgrade {
			rebootingForFirmwareUpgrade = false
			transferFirmware()
		}
	}

	public func upload(bin: Data, dat: Data, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {

		guard let firmware = DFUFirmware(binFile:bin, datFile:dat, type: .application) else {
			throw "Could not create firmware from given data"
		}

		triggerPairing()

		initiator = DFUServiceInitiator().with(firmware: firmware)
		initiator?.logger = logReceiver
		initiator?.delegate = statusDelegate
		initiator?.progressDelegate = progressReceiver

		try reboot()
	}

	public func cancelUpload() -> Bool {
		let success = uploader?.abort()
		if success ?? false {
			uploader = nil
		}
		return success ?? false
	}

	private func triggerPairing() {
		//this apparently triggers pairing and is necessary before DFU characteristic can be properly used
		//was like this in the old app version
		_ = try? read(characteristic: .dfuControl)
	}

	private func reboot() throws {
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
}
