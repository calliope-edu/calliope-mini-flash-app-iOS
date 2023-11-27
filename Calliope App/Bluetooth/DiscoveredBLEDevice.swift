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
    
    var usageReadyCalliope: FlashableCalliope?
    
    var serviceToDiscoveredCharacteristicsMap = [CBUUID : Set<CBUUID>]()

    var rebootingCalliope: FlashableCalliope? = nil

	enum CalliopeBLEDeviceState {
		case discovered //discovered and ready to connect, not connected yet
		case connected //connected, but services and characteristics have not (yet) been found
		case evaluateMode //connected, looking for services and characteristics
		case usageReady //all required services and characteristics have been found, calliope ready to be programmed
		case wrongMode //required services and characteristics not available, put into right mode
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
    
    lazy var servicesWithUndiscoveredCharacteristics: Set<CBUUID> = {
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
    
    public func shouldReconnectAfterReboot() -> Bool {
        return usageReadyCalliope?.shouldRebootOnDisconnect ?? false
    }

	// MARK: Services discovery

	/// evaluate whether calliope is in correct mode
    public func evaluateMode() {
        if let usageReadyCalliope = usageReadyCalliope, usageReadyCalliope.rebootingIntoDFUMode {
            LogNotify.log("Calliope is Rebooting For Firmwareupgrade, do not evaluate mode")
        } else if let rebootingCalliope = rebootingCalliope, rebootingCalliope.rebootingIntoDFUMode {
            LogNotify.log("RebootingCalliope exists do not evaluate mode")
        } else {
            LogNotify.log("Evaluating mode of calliope")
            //service discovery
            state = .evaluateMode
            peripheral.discoverServices([] + Self.discoverableServicesUUIDs)
        }
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
		guard error == nil else {
            
            LogNotify.log("Error discovering services \(error!)")
            
			LogNotify.log(error!.localizedDescription)
			state = .wrongMode
			return
		}

        let services = peripheral.services ?? []
		let uuidSet = Set(services.map { return $0.uuid })
        
        LogNotify.log("Did discover services \(services)")

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
        
        guard error == nil else {
            LogNotify.log("Error discovering characteristics \(error!)")
            
            LogNotify.log(error!.localizedDescription)
            state = .wrongMode
            return
        }
        
        let characteristics = service.characteristics ?? []
        let uuidSet = Set(characteristics.map { return $0.uuid })
        serviceToDiscoveredCharacteristicsMap[service.uuid] = uuidSet
        
        LogNotify.log("Did discover characteristics \(uuidSet)")

        //Only continue once every discovered service has atleast been checked for characteristic
        servicesWithUndiscoveredCharacteristics.remove(service.uuid)
        
        if(servicesWithUndiscoveredCharacteristics.isEmpty) {
            
            LogNotify.log("Did discover characteristics for all discovered services")
                        
            guard let validBLECalliope = FlashableCalliopeFactory.getFlashableCalliopeForBLEDevice(device: self) else {
                state = .wrongMode
                return
            }
            
            if let rebootingCalliope = rebootingCalliope, type(of: rebootingCalliope) === type(of: validBLECalliope) {
                LogNotify.log("Choose rebooting calliope for use")
                // We saved a calliope in a reboot process, use that one
                usageReadyCalliope = rebootingCalliope
            } else {
                //new calliope found, delegate was set in initialization process
                usageReadyCalliope = validBLECalliope
            }
            
            self.peripheral.delegate = usageReadyCalliope
            
            rebootingCalliope = nil
            
            state = .usageReady
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
