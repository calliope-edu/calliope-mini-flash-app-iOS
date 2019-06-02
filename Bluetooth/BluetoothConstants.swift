//
//  BluetoothConstants.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 23.02.19.
//

import Foundation

struct BluetoothConstants {
	static let discoveryTimeout = 20.0
	static let connectTimeout = 5.0
	static let readTimeout = 2.0
	static let writeTimeout = 2.0

	//set this to 0 of coupling is not necessary
	static let couplingDelay = 0.0
	//this should be a little longer than the duration (in seconds)
	//that the calliope needs for restarting in program 5
	static let restartDuration = 2.0

	static let lastConnectedKey = "cc.calliope.latestDeviceKey"
	static let lastConnectedNameKey = "name"
	static let lastConnectedUUIDKey = "uuidString"
	static let deviceNames = ["calliope", "micro:bit"]
}
