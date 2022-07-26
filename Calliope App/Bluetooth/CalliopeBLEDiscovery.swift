//
//  CalliopeBLEDiscovery.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 08.12.18.
//

import UIKit
import CoreBluetooth

class CalliopeBLEDiscovery: NSObject, CBCentralManagerDelegate {

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
    var errorBlock: (Error) -> () = {_ in }

	var calliopeBuilder: (_ peripheral: CBPeripheral, _ name: String) -> CalliopeBLEDevice

	private(set) var state : CalliopeDiscoveryState = .initialized {
		didSet {
			LogNotify.log("calliope discovery state: \(state)")
			updateQueue.async { self.updateBlock() }
		}
	}

	private(set) var discoveredCalliopes : [String : CalliopeBLEDevice] = [:] {
		didSet {
			LogNotify.log("discovered: \(discoveredCalliopes)")
			redetermineState()
		}
	}

	private var discoveredCalliopeUUIDNameMap : [UUID : String] = [:]

	private(set) var connectingCalliope: CalliopeBLEDevice? {
		didSet {
			if let connectingCalliope = self.connectingCalliope {
				connectedCalliope = nil
				self.centralManager.connect(connectingCalliope.peripheral, options: nil)
				//manual timeout (system timeout is too long)
				bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.connectTimeout) {
					if self.connectedCalliope == nil {
                        LogNotify.log("disabling auto connect for \(connectingCalliope)")
                        connectingCalliope.autoConnect = false
                        self.centralManager.cancelPeripheralConnection(connectingCalliope.peripheral)
                        self.updateQueue.async { self.errorBlock( NSLocalizedString("Connection to calliope timed out!", comment: "") ) }
					}
				}
			}
			redetermineState()
		}
	}

	private(set) var connectedCalliope: CalliopeBLEDevice? {
		didSet {
			if let uuid = connectedCalliope?.peripheral.identifier,
				let name = discoveredCalliopeUUIDNameMap[uuid] {
				lastConnected = (uuid, name)
			}
			oldValue?.hasDisconnected()
			connectedCalliope?.hasConnected()
            if connectedCalliope != nil {
                connectingCalliope = nil
            }
            redetermineState()
		}
	}

	private let bluetoothQueue = DispatchQueue.global(qos: .userInitiated)
	private lazy var centralManager: CBCentralManager = {
		return CBCentralManager(delegate: nil, queue: bluetoothQueue)
	}()

	private var lastConnected: (UUID, String)? {
		get {
			let defaults = UserDefaults.standard
			guard let dict = defaults.dictionary(forKey: BluetoothConstants.lastConnectedKey),
				let name = dict[BluetoothConstants.lastConnectedNameKey] as? String,
				let uuidString = dict[BluetoothConstants.lastConnectedUUIDKey] as? String,
				let uuid = UUID(uuidString: uuidString)
			else { return nil }
			return (uuid, name)
		}
		set {
			let defaults = UserDefaults.standard
			guard let newUUIDString = newValue?.0.uuidString,
				let newName = newValue?.1
			else {
				defaults.removeObject(forKey: BluetoothConstants.lastConnectedKey)
				return
			}
			defaults.setValue([BluetoothConstants.lastConnectedNameKey: newName,
							   BluetoothConstants.lastConnectedUUIDKey: newUUIDString],
							  forKey: BluetoothConstants.lastConnectedKey)
		}
	}

	init(_ calliopeBuilder: @escaping (_ peripheral: CBPeripheral, _ name: String) -> CalliopeBLEDevice) {
		self.calliopeBuilder = calliopeBuilder
		super.init()
        if centralManager.state == .poweredOn {
            attemptReconnect()
        }
		centralManager.delegate = self
	}

	private func redetermineState() {
		if connectedCalliope != nil {
			state = .connected
            for calliope in discoveredCalliopes {
                calliope.value.autoConnect = true
            }
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

		let calliope = calliopeBuilder(lastCalliope, lastConnectedName)

		self.discoveredCalliopes.updateValue(calliope, forKey: lastConnectedName)
		self.discoveredCalliopeUUIDNameMap.updateValue(lastConnectedName, forKey: lastCalliope.identifier)
		//auto-reconnect
		LogNotify.log("reconnect to: \(calliope)")
        delay(time: 0) {
            self.connectingCalliope = calliope
        }
	}
    
    
    /// allows another CalliopeBLEDiscovery to use lastConnected variable to reconnect to the same calliope
    public func giveUpResponsibility() {
        self.updateBlock = {}
        self.stopCalliopeDiscovery()
        //we disconnect manually here after switching off delegate, since we don´t want to wipe lastconnected setting
        centralManager.delegate = nil
        if let connectedCalliope = self.connectedCalliope {
            self.centralManager.cancelPeripheralConnection(connectedCalliope.peripheral)
        }
    }

	// MARK: discovery

	func startCalliopeDiscovery() {
		//start scan only if central manger already connected to bluetooth system service (=poweredOn)
		//alternatively, this is invoked after the state of the central mananger changed to poweredOn.
		if centralManager.state != .poweredOn {
            updateQueue.async { self.errorBlock(NSLocalizedString("Activate Bluetooth!", comment: "")) }
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
				let calliope = calliopeBuilder(peripheral, friendlyName)
				discoveredCalliopes.updateValue(calliope, forKey: friendlyName)
				discoveredCalliopeUUIDNameMap.updateValue(friendlyName, forKey: peripheral.identifier)
			}
		}
	}

	// MARK: connection

	func connectToCalliope(_ calliope: CalliopeBLEDevice) {
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
            updateQueue.async { self.errorBlock(NSLocalizedString("Could not find connected calliope in discovered calliopes", comment: "")) }
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
        if let error = error {
            updateQueue.async { self.errorBlock(error) }
        }
		connectingCalliope = nil
	}

	// MARK: state of the bluetooth manager

	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		switch central.state {
		case .poweredOn:
			startCalliopeDiscovery()
			if lastConnected != nil {
                self.attemptReconnect()
			}
		case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
			//bluetooth is in a state where we cannot do anything
			discoveredCalliopes = [:]
			discoveredCalliopeUUIDNameMap = [:]
			state = .initialized
		@unknown default:
			break
		}
	}
}
