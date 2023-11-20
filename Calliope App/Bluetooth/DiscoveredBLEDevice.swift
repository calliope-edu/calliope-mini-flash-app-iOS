//
//  CalliopeBLEDevice.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 08.12.18.
//

import UIKit
import CoreBluetooth

class DiscoveredBLEDDevice: NSObject, CBPeripheralDelegate {

    public static let usageReadyNotificationName = NSNotification.Name("calliope_is_usage_ready")
    public static let disconnectedNotificationName = NSNotification.Name("calliope_connection_lost")

    private let bluetoothQueue = DispatchQueue.global(qos: .userInitiated)

    //discoverable Services of the BLE Devices
    static var discoverableServices: Set<CalliopeService> = [.secureDfuService, .dfuControlService, .partialFlashing]
    static var discoverableServicesUUIDs: Set<CBUUID> = Set(discoverableServices.map { $0.uuid })
    
    //discovered Services of the BLE Device
    final var discoveredServices: Set<CalliopeService> = []
    lazy var discoveredServicesUUIDs: Set<CBUUID> = Set(discoveredServices.map { $0.uuid })
    
    
    var serviceToDiscoveredCharacteristicsMap = [CalliopeService : Set<CBUUID>]()


	enum CalliopeBLEDeviceState {
		case discovered //discovered and ready to connect, not connected yet
		case connected //connected, but services and characteristics have not (yet) been found
		case evaluateMode //connected, looking for services and characteristics
		case usageReady //all required services and characteristics have been found, calliope ready to be programmed
		case wrongMode //required services and characteristics not available, put into right mode
		case willReset //when a reset is done to enable or disable services
	}

	var state : CalliopeBLEDeviceState = .discovered {
		didSet {
			LogNotify.log("calliope state: \(state)")
			handleStateUpdate(oldValue)
            if usageReadyCalliope != nil {
                usageReadyCalliope?.notify(aboutState: state)
            }
		}
	}

    private func handleStateUpdate(_ oldState: CalliopeBLEDeviceState) {
		updateQueue.async { self.updateBlock() }
		if state == .discovered {
            discoveredServices = []
            if oldState == .usageReady {
                NotificationCenter.default.post(name: DiscoveredBLEDDevice.disconnectedNotificationName, object: self)
            }
		} else if state == .connected {
			//immediately evaluate whether in playground mode
            updateQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.couplingDelay) {
				self.evaluateMode()
			}
        } else if state == .evaluateMode {
            peripheral.delegate = self
            self.bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.serviceDiscoveryTimeout) {
                //has not discovered all services in time, probably stuck
                if self.state == .evaluateMode {
                    self.updateQueue.async { self.errorBlock(NSLocalizedString("Service discovery on calliope has timed out!", comment: "")) }
                    self.state = .wrongMode
                }
            }
        } else if state == .usageReady {
            NotificationCenter.default.post(name: DiscoveredBLEDDevice.usageReadyNotificationName,
                                            object: self)
        }
	}

	var updateQueue = DispatchQueue.main
	var updateBlock: () -> () = {}
    var errorBlock: (Error) -> () = { _ in }

	let peripheral : CBPeripheral
	let name : String
    

	required init(peripheral: CBPeripheral, name: String) {
		self.peripheral = peripheral
		self.name = name
		super.init()
		peripheral.delegate = self
	}
    
    var usageReadyCalliope: FlashableCalliope?
    
    lazy var servicesLeftToDiscoverFor: Set<CBUUID> = {
        return discoveredServicesUUIDs
    }()


	public func hasConnected() {
		if state == .discovered {
			state = .connected
		}
	}

	public func hasDisconnected() {
		if state != .discovered {
			state = .discovered
		}
	}

	// MARK: Services discovery

	/// evaluate whether calliope is in correct mode
    public func evaluateMode() {
		//service discovery
		state = .evaluateMode
        peripheral.discoverServices([] + Self.discoverableServicesUUIDs)
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		guard error == nil else {
			LogNotify.log(error!.localizedDescription)
			state = .wrongMode
			return
		}

        let services = peripheral.services ?? []
		let uuidSet = Set(services.map { return $0.uuid })

        let discoveredServiceUUIDs = uuidSet
        discoveredServices = Set(discoveredServiceUUIDs.compactMap { CalliopeBLEProfile.uuidServiceMap[$0] })
        services
            .forEach { service in
                peripheral.discoverCharacteristics(
                    CalliopeBLEProfile.serviceCharacteristicUUIDMap[service.uuid], for: service)
        }
        
        //Discovered All Services, Flashablecalliope with correct Version can now be created
	}
    
    // MARK: Characteristics discovery

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let requiredCharacteristicsUUIDs = Set(CalliopeBLEProfile.serviceCharacteristicUUIDMap[service.uuid] ?? [])
        let characteristics = service.characteristics ?? []
        let uuidSet = Set(characteristics.map { return $0.uuid })
        
        if uuidSet.isSuperset(of: requiredCharacteristicsUUIDs) {
            var serviceDiscoveredFor = CalliopeBLEProfile.uuidServiceMap[service.uuid]
            serviceToDiscoveredCharacteristicsMap[serviceDiscoveredFor!] = requiredCharacteristicsUUIDs
        } else {
            state = .wrongMode
        }
        //Only continue once every discovered service has atleast been checked for characteristic
        servicesLeftToDiscoverFor.remove(service.uuid)
        if(servicesLeftToDiscoverFor.isEmpty) {
            usageReadyCalliope = FlashableCalliopeFactory.getFlashableCalliopeForBLEDevice(device: self)
            if usageReadyCalliope != nil {
                state = .usageReady
            } else {
                // Delegate has been set to Calliope during creation, needs to be reset
                state = .wrongMode
            }
        } else {
            
        }
    }
}

//MARK: Equatable (conformance inherited default implementation by NSObject)

extension DiscoveredBLEDDevice {
	/*static func == (lhs: CalliopeBLEDevice, rhs: CalliopeBLEDevice) -> Bool {
		return lhs.peripheral == rhs.peripheral
	}*/

	override func isEqual(_ object: Any?) -> Bool {
		return self.peripheral == (object as? DiscoveredBLEDDevice)?.peripheral
	}
}

//MARK: CustomStringConvertible (conformance inherited default implementation by NSObject)

extension DiscoveredBLEDDevice {
	override var description: String {
		return "name: \(String(describing: name)), state: \(state)"
	}
}
