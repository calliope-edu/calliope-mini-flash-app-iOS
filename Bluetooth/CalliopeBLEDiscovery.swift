//
//  CalliopeBLEDiscovery.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 08.12.18.
//

import UIKit
import CoreBluetooth

class CalliopeBLEDiscovery<C: CalliopeBLEDevice>: NSObject, CBCentralManagerDelegate {

	enum CalliopeDiscoveryState {
		case initialized //no discovered calliopes, doing nothing
		case discoveryWaitingForBluetooth //invoked discovery but waiting for the system bluetooth (might be off)
		case discovering //running the discovery process now, but not discovered anything yet
		case discovered //discovery list is not empty, still searching
		case discoveredAll //discovery has finished with discovered calliopes
		case connecting //connecting to some calliope
		case connected //connected to some calliope
	}

	var updateQueue = DispatchQueue.main
	var updateBlock: () -> () = {}

	private(set) var state : CalliopeDiscoveryState = .initialized {
		didSet {
			LogNotify.log("calliope discovery state: \(state)")
			updateQueue.async { self.updateBlock() }
		}
	}

	private(set) var discoveredCalliopes : [String : C] = [:] {
		didSet {
			LogNotify.log("discovered: \(discoveredCalliopes)")
			redetermineState()
		}
	}

	private var discoveredCalliopeUUIDNameMap : [UUID : String] = [:]

	private(set) var connectingCalliope: C? {
		didSet {
			if let connectingCalliope = self.connectingCalliope {
				connectedCalliope = nil
				self.centralManager.connect(connectingCalliope.peripheral, options: nil)
				//manual timeout (system timeout is too long)
				bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.connectTimeout) {
					if self.connectedCalliope == nil {
						self.centralManager.cancelPeripheralConnection(connectingCalliope.peripheral)
					}
				}
			}
			redetermineState()
		}
	}

	private(set) var connectedCalliope: C? {
		didSet {
			if connectedCalliope != nil {
				connectingCalliope = nil
			}
			if let uuid = connectedCalliope?.peripheral.identifier,
				let name = discoveredCalliopeUUIDNameMap[uuid] {
				lastConnected = (uuid, name)
			}
			redetermineState()
			oldValue?.hasDisconnected()
			connectedCalliope?.hasConnected()
		}
	}

	private let bluetoothQueue = DispatchQueue.global(qos: .userInitiated)
	private lazy var centralManager: CBCentralManager = {
		return CBCentralManager(delegate: nil, queue: bluetoothQueue)
	}()

	private var lastConnected: (UUID, String)? {
		get {
			/*TODO: reenable let store = PlaygroundKeyValueStore.current
			guard case let .dictionary(dict)? = store[BluetoothConstants.lastConnectedKey],
				case let .string(name)? = dict[BluetoothConstants.lastConnectedNameKey],
				case let .string(uuidString)? = dict[BluetoothConstants.lastConnectedUUIDKey],
				let uuid = UUID(uuidString: uuidString)
			else { return nil }
			return (uuid, name)*/
			return nil
		}
		set {
			/*
			let store = PlaygroundKeyValueStore.current
			guard let newUUIDString = newValue?.0.uuidString,
				let newName = newValue?.1
			else {
				store[BluetoothConstants.lastConnectedKey] = nil
				return
			}
			store[BluetoothConstants.lastConnectedKey] = .dictionary([BluetoothConstants.lastConnectedNameKey: .string(newName),
													   BluetoothConstants.lastConnectedUUIDKey: .string(newUUIDString)])
			*/
		}
	}

	override init() {
		super.init()
		centralManager.delegate = self
	}

	private func redetermineState() {
		if connectedCalliope != nil {
			state = .connected
		} else if connectingCalliope != nil {
			state = .connecting
		} else if centralManager.isScanning {
			state = discoveredCalliopes.isEmpty ? .discovering : .discovered
		} else {
			state = discoveredCalliopes.isEmpty ? .initialized : .discoveredAll
		}
	}

	private func attemptReconnect() {
		LogNotify.log("attempt reconnect")
		guard let (lastConnectedUUID, lastConnectedName) = self.lastConnected,
		let lastCalliope = centralManager.retrievePeripherals(withIdentifiers: [lastConnectedUUID]).first
		else { return }

		let calliope = C(peripheral: lastCalliope, name: lastConnectedName)

		self.discoveredCalliopes.updateValue(calliope, forKey: lastConnectedName)
		self.discoveredCalliopeUUIDNameMap.updateValue(lastConnectedName, forKey: lastCalliope.identifier)
		//auto-reconnect
		LogNotify.log("reconnect to: \(calliope)")
		connectingCalliope = calliope
	}

	// MARK: discovery

	func startCalliopeDiscovery() {
		//start scan only if central manger already connected to bluetooth system service (=poweredOn)
		//alternatively, this is invoked after the state of the central mananger changed to poweredOn.
		if centralManager.state != .poweredOn {
			state = .discoveryWaitingForBluetooth
		} else if !centralManager.isScanning {
			centralManager.scanForPeripherals(withServices: nil, options: nil)
			//stop the search after some time. The user can invoke it again later.
			bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.discoveryTimeout) {
				self.stopCalliopeDiscovery()
			}
			redetermineState()
		}
	}

	func stopCalliopeDiscovery() {
		if centralManager.isScanning {
			self.centralManager.stopScan()
		}
		redetermineState()
	}

	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		if let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber,
			connectable.boolValue == true,
			let localName = advertisementData[CBAdvertisementDataLocalNameKey],
			let lowerName = (localName as? String)?.lowercased(),
			BluetoothConstants.deviceNames.map({ lowerName.contains($0) }).contains(true),
			let friendlyName = Matrix.full2Friendly(fullName: lowerName) {
			//FIXME: hard-coded name for testing
			//let friendlyName = Optional("gepeg") {
			//never create a calliope twice, since this would clear its state
			if discoveredCalliopes[friendlyName] == nil {
				//we found a calliope device (or one that pretends to be a calliope at least)
				let calliope = C(peripheral: peripheral, name: friendlyName)
				discoveredCalliopes.updateValue(calliope, forKey: friendlyName)
				discoveredCalliopeUUIDNameMap.updateValue(friendlyName, forKey: peripheral.identifier)
			}
		}
	}

	// MARK: connection

	func connectToCalliope(_ calliope: C) {
		//when we first connect, we stop searching further
		stopCalliopeDiscovery()
		//do not connect twice
		guard calliope != connectedCalliope else { return }
		//reset last connected, we attempt to connect to a new callipoe now
		lastConnected = nil
		connectingCalliope = calliope
	}

	func disconnectFromCalliope() {
		if let connectedCalliope = self.connectedCalliope {
			self.centralManager.cancelPeripheralConnection(connectedCalliope.peripheral)
		}
		//preemptively update connected calliope, in case delegate call does not happen
		self.connectedCalliope = nil
	}

	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		guard let name = discoveredCalliopeUUIDNameMap[peripheral.identifier],
			let calliope = discoveredCalliopes[name] else {
				//TODO: log that we encountered unexpected behavior
				return
		}
		connectedCalliope = calliope
	}

	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		LogNotify.log("disconnected from \(peripheral.name ?? "unknown device"))")
		connectingCalliope = nil
		connectedCalliope = nil
		lastConnected = nil
	}

	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
		//TODO: remove calliope from discovered list depending on error
		connectingCalliope = nil
	}

	// MARK: state of the bluetooth manager

	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		switch central.state {
		case .poweredOn:
			startCalliopeDiscovery()
			if lastConnected != nil {
				attemptReconnect()
			}
		case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
			//bluetooth is in a state where we cannot do anything
			discoveredCalliopes = [:]
			discoveredCalliopeUUIDNameMap = [:]
			state = .initialized
		}
	}
}
