//
//  SecureFlashableCalliope.swift
//  Calliope App
//
//  Created by itestra on 13.11.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import CoreBluetooth
import NordicDFU
import UIKit

class BLECalliope: Calliope {

    //the services required for the usage
    var requiredServices: Set<CalliopeService> {
        []
    }

    //servcies that are not strictly necessary
    var optionalServices: Set<CalliopeService> {
        []
    }

    final var discoveredOptionalServices: Set<CalliopeService> = []

    lazy var requiredServicesUUIDs: Set<CBUUID> = Set(
        requiredServices.map {
            $0.uuid
        })

    lazy var optionalServicesUUIDs: Set<CBUUID> = Set(
        optionalServices.map {
            $0.uuid
        })

    var updateQueue = DispatchQueue.main


    let peripheral: CBPeripheral
    let name: String
    let servicesChangedCallback: () -> ()?

    required init?(peripheral: CBPeripheral, name: String, discoveredServices: Set<CalliopeService>, discoveredCharacteristicUUIDsForServiceUUID: [CBUUID: Set<CBUUID>], servicesChangedCallback: @escaping () -> ()?) {
        self.peripheral = peripheral
        self.name = name
        self.servicesChangedCallback = servicesChangedCallback
        super.init()

        self.discoveredOptionalServices = discoveredServices.intersection(optionalServices)
        guard validateServicesAndCharacteristics(discoveredServices, peripheral, discoveredCharacteristicUUIDsForServiceUUID) else {
            LogNotify.log("failed to find required services or a way to activate them for \(String(describing: self))")
            return nil
        }

        LogNotify.log("successfully validated Calliope Type \(String(describing: self))")
    }

    private func validateServicesAndCharacteristics(_ discoveredServices: Set<CalliopeService>, _ peripheral: CBPeripheral, _ discoveredCharacteristicUUIDsForServiceUUID: [CBUUID: Set<CBUUID>]) -> Bool {
        LogNotify.log("start validating optional and required services")
        //Validate Services, are required Services discovered
        let requiredServicesUUIDs = Set(
            requiredServices.map {
                return $0.uuid
            })
        let discoveredOptionalServices = optionalServices.intersection(discoveredServices)

        guard requiredServices.isSubset(of: discoveredServices) else {
            return false
        }

        LogNotify.log("Found all \(requiredServicesUUIDs.count) required services: \(requiredServices)")
        LogNotify.log("Found \(discoveredOptionalServices.count) of \(optionalServices.count) optional Services: \(discoveredOptionalServices)")

        //Validate Characteristics, are characteristics discovered for all optional and required services
        // Previous logic looked that the characteristics of the required service is found, which was a 1-1 relation. Now, it is 1-n where n has to be at least one of the characteristics
        for service in requiredServices {
            guard let foundCharacteristics = discoveredCharacteristicUUIDsForServiceUUID[service.uuid], !foundCharacteristics.isEmpty, foundCharacteristics.isSubset(of: CalliopeBLEProfile.serviceCharacteristicUUIDMap[service.uuid] ?? []) else {
                LogNotify.log("Some characteristics not found for service \(service.uuid)")
                return false
            }
            LogNotify.log("All characteristics \(foundCharacteristics) found for service \(service.uuid)")
        }

        return true
    }


    //MARK: reading and writing characteristics (asynchronously/ scheduled/ synchronously)
    //to sequentialize reads and writes

    let readWriteQueue = DispatchQueue.global(qos: .userInitiated)
    let readWriteSem = DispatchSemaphore(value: 1)
    var readWriteGroup: DispatchGroup? = nil

    var writeError: Error? = nil
    var writingCharacteristic: CBCharacteristic? = nil

    var readError: Error? = nil
    var readingCharacteristic: CBCharacteristic? = nil
    var readValue: Data? = nil

    var setNotifyError: Error? = nil
    var notifyingCharacteristic: CBCharacteristic? = nil

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let writingCharacteristic = writingCharacteristic, characteristic.uuid == writingCharacteristic.uuid {
            explicitWriteResponse(error)
            return
        } else {
            LogNotify.log("didWrite called for characteristic that we did not write to!")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        LogNotify.log("Calliope \(peripheral.name ?? "[no name]") invalidated services \(invalidatedServices). Re-evaluate mode.")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.servicesChangedCallback()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        if let readingCharac = readingCharacteristic, characteristic.uuid == readingCharac.uuid {
            explicitReadResponse(for: characteristic, error: error)
            return
        }

        guard error == nil, let value = characteristic.value else {
            LogNotify.log(readError?.localizedDescription ?? "characteristic \(characteristic.uuid) does not have a value")
            return
        }

        guard let calliopeCharacteristic = CalliopeBLEProfile.uuidCharacteristicMap[characteristic.uuid]
        else {
            LogNotify.log("received value from unknown characteristic: \(characteristic.uuid)")
            return
        }

        //        handleValueUpdateInternal(calliopeCharacteristic, value) ? Why ?
        handleValueUpdate(calliopeCharacteristic, value)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let writingCharacteristic = notifyingCharacteristic, characteristic.uuid == writingCharacteristic.uuid {
            explicitSetNotifyResponse(error)
            return
        } else {
            LogNotify.log("updated notification state for for characteristic that we did not subscribe to!")
        }
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

    private func explicitSetNotifyResponse(_ error: Error?) {
        notifyingCharacteristic = nil
        //set potential error and move on
        setNotifyError = error
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

    func getCBCharacteristic(_ characteristic: CalliopeCharacteristic) -> CBCharacteristic? {
        guard let serviceUuid = CalliopeBLEProfile.characteristicServiceMap[characteristic]?.uuid
        else {
            return nil
        }
        let uuid = characteristic.uuid
        return peripheral.services?.first {
            $0.uuid == serviceUuid
        }?
        .characteristics?.first {
            $0.uuid == uuid
        }
    }

    func write(_ data: Data, for characteristic: CalliopeCharacteristic) throws {
        let cbCharacteristic = try checkWritePreconditions(for: characteristic)
        try write(data, for: cbCharacteristic)
    }

    func writeWithoutResponse(_ data: Data, for characteristic: CalliopeCharacteristic) throws {
        let cbCharacteristic = try checkWritePreconditions(for: characteristic)
        peripheral.writeValue(data, for: cbCharacteristic, type: .withoutResponse)
    }

    private func checkWritePreconditions(for characteristic: CalliopeCharacteristic) throws -> CBCharacteristic {
        guard let serviceForCharacteristic = CalliopeBLEProfile.characteristicServiceMap[characteristic],
            requiredServices.contains(serviceForCharacteristic) || discoveredOptionalServices.contains(serviceForCharacteristic)
        else {
            throw "Not ready to write to characteristic \(characteristic)"
        }
        guard let cbCharacteristic = getCBCharacteristic(characteristic) else {
            throw "characteristic \(characteristic) not available"
        }
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
        guard let cbCharacteristic = getCBCharacteristic(characteristic)
        else {
            throw "no service that contains characteristic \(characteristic)"
        }
        return try read(characteristic: cbCharacteristic)
    }

    func read(characteristic: CBCharacteristic) throws -> Data? {
        return try applySemaphore(readWriteSem) {
            readingCharacteristic = characteristic

            asyncAndWait(on: readWriteQueue) {
                //read value and wait for delegate call (or error)
                self.readWriteGroup = DispatchGroup()
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

    func setNotify(characteristic: CalliopeCharacteristic, _ activate: Bool) throws {
        guard let cbCharacteristic = getCBCharacteristic(characteristic)
        else {
            throw "no service that contains characteristic \(characteristic)"
        }
        return try setNotify(characteristic: cbCharacteristic, activate)
    }

    func setNotify(characteristic: CBCharacteristic, _ activate: Bool) throws {
        return try applySemaphore(readWriteSem) {
            notifyingCharacteristic = characteristic

            asyncAndWait(on: readWriteQueue) {
                //read value and wait for delegate call (or error)
                self.readWriteGroup = DispatchGroup()
                self.readWriteGroup!.enter()
                self.peripheral.setNotifyValue(activate, for: characteristic)
                if self.readWriteGroup!.wait(timeout: DispatchTime.now() + BluetoothConstants.readTimeout) == .timedOut {
                    LogNotify.log("activate notifications from \(characteristic) timed out")
                    self.setNotifyError = CBError(.connectionTimeout)
                }
            }

            guard setNotifyError == nil else {
                LogNotify.log("read resulted in error: \(setNotifyError!)")
                let error = setNotifyError!
                //prepare for next read
                setNotifyError = nil
                throw error
            }
        }
    }
}
