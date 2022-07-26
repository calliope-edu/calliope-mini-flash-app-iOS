//
//  CalliopeBLEDevice.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 08.12.18.
//

import UIKit
import CoreBluetooth

class CalliopeBLEDevice: NSObject, CBPeripheralDelegate {

    public static let usageReadyNotificationName = NSNotification.Name("calliope_is_usage_ready")
    public static let disconnectedNotificationName = NSNotification.Name("calliope_connection_lost")

    private let bluetoothQueue = DispatchQueue.global(qos: .userInitiated)

	//the services required for the usage
	var requiredServices : Set<CalliopeService> {
		fatalError("The CalliopeBLEDevice Class is abstract! At least requiredServices variable must be overridden by subclass.")
	}
    //servcies that are not strictly necessary
    var optionalServices : Set<CalliopeService> { [] }

    final var discoveredOptionalServices: Set<CalliopeService> = []

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
			handleStateUpdateInternal(oldValue)
			handleStateUpdate()
		}
	}

	func handleStateUpdate() {
		//default implementation does nothing
	}

    private func handleStateUpdateInternal(_ oldState: CalliopeBLEDeviceState) {
		updateQueue.async { self.updateBlock() }
		if state == .discovered {
			//services get invalidated, undiscovered characteristics are thus restored (need to re-discover)
            servicesWithUndiscoveredCharacteristics = requiredServicesUUIDs.union(optionalServicesUUIDs)
            discoveredOptionalServices = []
            if oldState == .usageReady {
                NotificationCenter.default.post(name: CalliopeBLEDevice.disconnectedNotificationName, object: self)
            }
		} else if state == .connected {
			//immediately evaluate whether in playground mode
            updateQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.couplingDelay) {
				self.evaluateMode()
			}
        } else if state == .evaluateMode {
            self.bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.serviceDiscoveryTimeout) {
                //has not discovered all services in time, probably stuck
                if self.state == .evaluateMode {
                    self.updateQueue.async { self.errorBlock(NSLocalizedString("Service discovery on calliope has timed out!", comment: "")) }
                    self.state = .wrongMode
                }
            }
        } else if state == .usageReady {
            NotificationCenter.default.post(name: CalliopeBLEDevice.usageReadyNotificationName,
                                            object: self)
        }
	}

	var updateQueue = DispatchQueue.main
	var updateBlock: () -> () = {}
    var errorBlock: (Error) -> () = { _ in }

	let peripheral : CBPeripheral
	let name : String
    var autoConnect : Bool = true

	lazy var servicesWithUndiscoveredCharacteristics: Set<CBUUID> = {
        return requiredServicesUUIDs.union(optionalServicesUUIDs)
	}()

    lazy var requiredServicesUUIDs: Set<CBUUID> = Set(requiredServices.map { $0.uuid })

    lazy var optionalServicesUUIDs: Set<CBUUID> = Set(optionalServices.map { $0.uuid })

	required init(peripheral: CBPeripheral, name: String) {
		self.peripheral = peripheral
		self.name = name
		super.init()
		peripheral.delegate = self
		_ = requiredServices
	}

	public func hasConnected() {
		if state == .discovered {
			state = .connected
            autoConnect = true
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
		peripheral.discoverServices([CalliopeService.master.uuid] + requiredServicesUUIDs + optionalServicesUUIDs)
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		guard error == nil else {
			LogNotify.log(error!.localizedDescription)
			state = .wrongMode
			return
		}

        let services = peripheral.services ?? []
		let uuidSet = Set(services.map { return $0.uuid })

        let discoveredOptionalServiceUUIDs = uuidSet.intersection(optionalServicesUUIDs)
        discoveredOptionalServices = Set(discoveredOptionalServiceUUIDs.compactMap { CalliopeBLEProfile.uuidServiceMap[$0] })

        //evaluate whether all required services were found. If not, Calliope is not ready for programs from the playground
		if uuidSet.isSuperset(of: requiredServicesUUIDs) {
			LogNotify.log("found all of \(requiredServicesUUIDs.count) required services:\n\(requiredServices)")
            LogNotify.log("found \(discoveredOptionalServices.count) of \(optionalServices.count) optional services")
			//discover the characteristics of all required services, just to be thorough
            servicesWithUndiscoveredCharacteristics = uuidSet.intersection(requiredServicesUUIDs.union(discoveredOptionalServiceUUIDs))
            services
                .filter { requiredServicesUUIDs.contains($0.uuid) || optionalServicesUUIDs.contains($0.uuid) }
                .forEach { service in
                    peripheral.discoverCharacteristics(
                        CalliopeBLEProfile.serviceCharacteristicUUIDMap[service.uuid], for: service)
			}
		} else if (uuidSet.contains(CalliopeService.master.uuid)) {
			//activate missing services
			LogNotify.log("attempt activation of required services through master service")
			guard let masterService = services.first(where: { $0.uuid == CalliopeService.master.uuid }) else {
				state = .wrongMode
				return
			}
			peripheral.discoverCharacteristics([CalliopeCharacteristic.services.uuid], for: masterService)
		} else {
			LogNotify.log("failed to find required services or a way to activate them")
			state = .wrongMode
		}
	}

	private func resetForRequiredServices() {
		guard requiredServices.reduce(true, { $0 && ($1.bitPattern != 0) }) else {
			LogNotify.log("services \(requiredServices) cannot be enabled through master service")
			state = .wrongMode
			return
		}
        let flags = ((requiredServices.union(optionalServices)).reduce(0, { $0 | $1 }) | 1 << 31).littleEndianData
		do { try write(flags, for: .services) }
		catch {
			if state == .evaluateMode {
				state = .wrongMode
			}
			LogNotify.log("was not able to enable services \(requiredServices) through master service")
		}
	}


	// MARK: Characteristics discovery

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

		if service.uuid == CalliopeService.master.uuid {
			//indicate that calliope & bluetooth connection is about to be reset programmatically
			self.state = .willReset
			updateQueue.async {
				//we searched the master service characteristics because we did not have all required characteristics
				LogNotify.log("resetting Calliope to enable required services")
				self.resetForRequiredServices()
				//in the future, just activate services on the fly
			}
		}

		let requiredCharacteristicsUUIDs = Set(CalliopeBLEProfile.serviceCharacteristicUUIDMap[service.uuid] ?? [])

		let characteristics = service.characteristics ?? []
		let uuidSet = Set(characteristics.map { return $0.uuid })

		if uuidSet.isSuperset(of: requiredCharacteristicsUUIDs) {
			_ = servicesWithUndiscoveredCharacteristics.remove(service.uuid)
		} else {
			state = .wrongMode
		}

		if servicesWithUndiscoveredCharacteristics.isEmpty {
			state = .usageReady
		}
	}

	func getCBCharacteristic(_ characteristic: CalliopeCharacteristic) -> CBCharacteristic? {
		guard state == .usageReady || state == .willReset,
			let serviceUuid = CalliopeBLEProfile.characteristicServiceMap[characteristic]?.uuid
			else { return nil }
		let uuid = characteristic.uuid
		return peripheral.services?.first { $0.uuid == serviceUuid }?
            .characteristics?.first { $0.uuid == uuid }
	}

	//MARK: reading and writing characteristics (asynchronously/ scheduled/ synchronously)

	//to sequentialize reads and writes

	let readWriteQueue = DispatchQueue.global(qos: .userInitiated)

	let readWriteSem = DispatchSemaphore(value: 1)

	var readWriteGroup: DispatchGroup? = nil

	var writeError : Error? = nil
	var writingCharacteristic : CBCharacteristic? = nil

	var readError : Error? = nil
	var readingCharacteristic : CBCharacteristic? = nil
	var readValue : Data? = nil

	func write (_ data: Data, for characteristic: CalliopeCharacteristic) throws {
        let cbCharacteristic = try checkWritePreconditions(for: characteristic)
		try write(data, for: cbCharacteristic)
	}

    func writeWithoutResponse(_ data: Data, for characteristic: CalliopeCharacteristic) throws {
        let cbCharacteristic = try checkWritePreconditions(for: characteristic)
        peripheral.writeValue(data, for: cbCharacteristic, type: .withoutResponse)
    }

    private func checkWritePreconditions(for characteristic: CalliopeCharacteristic) throws -> CBCharacteristic {
        guard state == .usageReady || state == .willReset,
              let serviceForCharacteristic = CalliopeBLEProfile.characteristicServiceMap[characteristic],
              requiredServices.contains(serviceForCharacteristic) || discoveredOptionalServices.contains(serviceForCharacteristic)
            else { throw "Not ready to write to characteristic \(characteristic)" }
        guard let cbCharacteristic = getCBCharacteristic(characteristic) else { throw "characteristic \(characteristic) not available" }
        return cbCharacteristic
    }

	func write(_ data: Data, for characteristic: CBCharacteristic) throws {
		try applySemaphore(readWriteSem) {
			writingCharacteristic = characteristic

			asyncAndWait(on: readWriteQueue) {
				//write value and wait for delegate call (or error)
				self.readWriteGroup = DispatchGroup()
				self.readWriteGroup!.enter()
				self.peripheral.writeValue(data, for: characteristic, type: .withResponse)

				if self.readWriteGroup!.wait(timeout: DispatchTime.now() + BluetoothConstants.writeTimeout) == .timedOut {
					LogNotify.log("write to \(characteristic) timed out")
					self.writeError = CBError(.connectionTimeout)
				}
			}

			guard writeError == nil else {
				LogNotify.log("write resulted in error: \(writeError!)")
				let error = writeError!
				//prepare for next write
				writeError = nil
				throw error
			}
			LogNotify.log("wrote \(characteristic)")
		}
	}

	func read(characteristic: CalliopeCharacteristic) throws -> Data? {
		guard state == .usageReady
			else { throw "Not ready to read characteristic \(characteristic)" }
		guard let cbCharacteristic = getCBCharacteristic(characteristic)
			else { throw "no service that contains characteristic \(characteristic)" }
		return try read(characteristic: cbCharacteristic)
	}

	func read(characteristic: CBCharacteristic) throws -> Data? {
		return try applySemaphore(readWriteSem) {
			readingCharacteristic = characteristic

			asyncAndWait(on: readWriteQueue) {
				//read value and wait for delegate call (or error)
				self.readWriteGroup = DispatchGroup();
				self.readWriteGroup!.enter()
				self.peripheral.readValue(for: characteristic)
				if self.readWriteGroup!.wait(timeout: DispatchTime.now() + BluetoothConstants.readTimeout) == .timedOut {
					LogNotify.log("read from \(characteristic) timed out")
					self.readError = CBError(.connectionTimeout)
				}
			}

			guard readError == nil else {
				LogNotify.log("read resulted in error: \(readError!)")
				let error = readError!
				//prepare for next read
				readError = nil
				throw error
			}

			let data = readValue
			LogNotify.log("read \(String(describing: data)) from \(characteristic)")
			readValue = nil
			return data
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
		if let writingCharac = writingCharacteristic, characteristic.uuid == writingCharac.uuid {
			explicitWriteResponse(error)
			return
		} else {
			LogNotify.log("didWrite called for characteristic that we did not write to!")
		}
	}

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        LogNotify.log("Calliope \(peripheral.name ?? "[no name]") invalidated services \(invalidatedServices). Re-evaluate mode.")
        evaluateMode()
    }

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

		if let readingCharac = readingCharacteristic, characteristic.uuid == readingCharac.uuid {
			explicitReadResponse(for: characteristic, error: error)
			return
		}

		guard error == nil, let value = characteristic.value else {
			LogNotify.log(readError?.localizedDescription ??
				"characteristic \(characteristic.uuid) does not have a value")
			return
		}

		guard let calliopeCharacteristic = CalliopeBLEProfile.uuidCharacteristicMap[characteristic.uuid]
			else {
				LogNotify.log("received value from unknown characteristic: \(characteristic.uuid)")
				return
		}

		handleValueUpdateInternal(calliopeCharacteristic, value)
		handleValueUpdate(calliopeCharacteristic, value)
	}

	func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {
		LogNotify.log("value for \(characteristic) updated (\(value.hexEncodedString()))")
	}

	private func handleValueUpdateInternal(_ characteristic: CalliopeCharacteristic, _ value: Data) {
		LogNotify.log("value for \(characteristic) updated (\(value.hexEncodedString()))")
	}

	private func explicitWriteResponse(_ error: Error?) {
		writingCharacteristic = nil
		//set potential error and move on
		writeError = error
		if let error = error {
			LogNotify.log("received error from writing: \(error)")
		} else {
			LogNotify.log("received write success message")
		}
		readWriteGroup?.leave()
	}

	private func explicitReadResponse(for characteristic: CBCharacteristic, error: Error?) {
		readingCharacteristic = nil
		//answer to explicit read request
		if let error = error {
			LogNotify.log("received error from reading \(characteristic): \(error)")
			readError = error
			LogNotify.log(error.localizedDescription)
		} else {
			readValue = characteristic.value
			LogNotify.log("received read response from \(characteristic): \(String(describing: readValue?.hexEncodedString()))")
		}
		readWriteGroup?.leave()
	}
}

//MARK: Equatable (conformance inherited default implementation by NSObject)

extension CalliopeBLEDevice {
	/*static func == (lhs: CalliopeBLEDevice, rhs: CalliopeBLEDevice) -> Bool {
		return lhs.peripheral == rhs.peripheral
	}*/

	override func isEqual(_ object: Any?) -> Bool {
		return self.peripheral == (object as? CalliopeBLEDevice)?.peripheral
	}
}

//MARK: CustomStringConvertible (conformance inherited default implementation by NSObject)

extension CalliopeBLEDevice {
	override var description: String {
		return "name: \(String(describing: name)), state: \(state)"
	}
}
