//
//  CalliopeBLEDiscovery.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 08.12.18.
//

import UIKit
import CoreBluetooth
import UniformTypeIdentifiers

class CalliopeDiscovery: NSObject, CBCentralManagerDelegate, UIDocumentPickerDelegate {

	enum CalliopeDiscoveryState {
		case initialized //no discovered calliopes, doing nothing
		case discoveryWaitingForBluetooth //invoked discovery but waiting for the system bluetooth (might be off)
		case discovering //running the discovery process now, but not discovered anything yet
		case discovered //discovery list is not empty, still searching
		case discoveredAll //discovery has finished with discovered calliopes
		case connecting //connecting to some calliope
		case connected //connected to some calliope
        case usbConnecting // connecting to a usb calliope
        case usbConnected // connected to a usb calliope
	}
    
    private static let usbCalliopeName = "USB_CALLIOPE"

	var updateQueue = DispatchQueue.main
	var updateBlock: () -> () = {}
    var errorBlock: (Error) -> () = {_ in }

	var calliopeBuilder: (_ peripheral: CBPeripheral, _ name: String) -> DiscoveredBLEDDevice

	private(set) var state : CalliopeDiscoveryState = .initialized {
		didSet {
			LogNotify.log("calliope discovery state: \(state)")
			updateQueue.async { self.updateBlock() }
		}
	}

	private(set) var discoveredCalliopes : [String : DiscoveredDevice] = [:] {
		didSet {
			LogNotify.log("discovered: \(discoveredCalliopes)")
			redetermineState()
		}
	}

	private var discoveredCalliopeUUIDNameMap : [UUID : String] = [:]

	private(set) var connectingCalliope: DiscoveredDevice? {
		didSet {
			if let connectingCalliope = self.connectingCalliope {
                if connectingCalliope is DiscoveredBLEDDevice {
                    LogNotify.log("Connect to Bluetooth Calliope")
                    let connectingBLECalliope = connectingCalliope as! DiscoveredBLEDDevice
                    connectedCalliope = nil
                    self.centralManager.connect(connectingBLECalliope.peripheral, options: nil)
                    //manual timeout (system timeout is too long)
                    bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + .seconds(BluetoothConstants.connectTimeout)) {
                        if self.connectedCalliope == nil {
                            LogNotify.log("disabling auto connect for \(connectingCalliope)")
                            self.centralManager.cancelPeripheralConnection(connectingBLECalliope.peripheral)
                            self.updateQueue.async { self.errorBlock( NSLocalizedString("Connection to calliope timed out!", comment: "") ) }
                        }
                    }
                } 
                if connectingCalliope is DiscoveredUSBDevice {
                    LogNotify.log("Connect to USB Calliope")
                    let connectingUSBCalliope = connectingCalliope as! DiscoveredUSBDevice
                    do {
                        connectedUSBCalliope = connectingUSBCalliope
                        connectedUSBCalliope?.usageReadyCalliope = try USBCalliope(calliopeLocation: connectingUSBCalliope.url)
                        print("Calliope Discovery State now: ")
                        print(state)
                    } catch {
                        LogNotify.log("Connecting to USB Calliope failed")
                    }
                    
                }
				
			}
			redetermineState()
		}
	}

	private(set) var connectedCalliope: DiscoveredBLEDDevice? {
		didSet {
			if let uuid = connectedCalliope?.peripheral.identifier,
				let name = discoveredCalliopeUUIDNameMap[uuid] {
				lastConnected = (uuid, name)
			}
			oldValue?.hasDisconnected()
			connectedCalliope?.hasConnected()
            if (connectedCalliope != nil) {
                connectingCalliope = nil
            }
            redetermineState()
		}
	}
    
    private(set) var connectedUSBCalliope: DiscoveredUSBDevice? {
        didSet {
            oldValue?.hasDisconnected()
            connectedUSBCalliope?.hasConnected()
            connectedUSBCalliope?.state = .usageReady
            if (connectedUSBCalliope != nil) {
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

	init(_ calliopeBuilder: @escaping (_ peripheral: CBPeripheral, _ name: String) -> DiscoveredBLEDDevice) {
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
        } else if connectedUSBCalliope != nil {
            state = .usbConnected
        } else if connectingCalliope != nil {
			state = .connecting
        } else if centralManager.isScanning && MatrixConnectionViewController.instance != nil && !MatrixConnectionViewController.instance.isInUsbMode{
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
            if !MatrixConnectionViewController.instance.isInUsbMode {
                updateQueue.async { self.errorBlock(NSLocalizedString("Activate Bluetooth!", comment: "")) }
                state = .discoveryWaitingForBluetooth
            }
		} else if !centralManager.isScanning {
            discoveredCalliopes = [:]
            discoveredCalliopeUUIDNameMap = [:]
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

	func connectToCalliope(_ calliope: DiscoveredDevice) {
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
        if connectedUSBCalliope != nil {
            connectedCalliope = nil
            discoveredCalliopes.removeValue(forKey: CalliopeDiscovery.usbCalliopeName)
        }
        self.connectedUSBCalliope = nil
		self.connectedCalliope = nil
	}
    
    func initializeConnectionToUsbCalliope(view: UIViewController) {
        state = .usbConnecting
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        view.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]){
        let url = urls.first
        let discoveredCalliope = DiscoveredUSBDevice(url: url!, name: CalliopeDiscovery.usbCalliopeName)
        if (discoveredCalliope == nil) {
            MatrixConnectionViewController.instance.showFalseLocationAlert()
            state = .initialized
        } else {
            discoveredCalliope!.state = DiscoveredDevice.CalliopeBLEDeviceState.discovered
            self.discoveredCalliopes.updateValue(discoveredCalliope!, forKey: CalliopeDiscovery.usbCalliopeName)
        }
    }

	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		guard let name = discoveredCalliopeUUIDNameMap[peripheral.identifier],
			let calliope = discoveredCalliopes[name] else {
            updateQueue.async { self.errorBlock(NSLocalizedString("Could not find connected calliope in discovered calliopes", comment: "")) }
            return
		}
        connectedCalliope = calliope as? DiscoveredBLEDDevice
	}

	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        LogNotify.log("disconnected from \(peripheral.name ?? "unknown device"), with error: \(error?.localizedDescription ?? "none")")
        // If Usage Ready Calliope is rebooting, automatically reconnect to the calliope
        if let connectedCalliope = connectedCalliope, connectedCalliope.shouldReconnectAfterReboot() {
            connectedCalliope.rebootingCalliope = connectedCalliope.usageReadyCalliope
            self.connectedCalliope = nil
            // Reconnect to Calliope after waiting for it having rebooted
            bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.restartDuration) {
                self.connectToCalliope(connectedCalliope)
            }
        } else {
            connectingCalliope = nil
            connectedCalliope = nil
            lastConnected = nil
        }
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
            if (state == .usbConnected || state == .usbConnecting) {
                return
            }
			//bluetooth is in a state where we cannot do anything
            connectingCalliope = nil
            connectedCalliope = nil
			discoveredCalliopes = [:]
			discoveredCalliopeUUIDNameMap = [:]
			state = .initialized
		@unknown default:
			break
		}
	}
}
