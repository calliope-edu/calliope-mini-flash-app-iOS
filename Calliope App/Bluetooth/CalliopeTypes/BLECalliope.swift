//
//  SecureFlashableCalliope.swift
//  Calliope App
//
//  Created by itestra on 13.11.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import UIKit
import iOSDFULibrary
import CoreBluetooth

class BLECalliope: NSObject, CBPeripheralDelegate {
    
    //the services required for the usage
    var requiredServices : Set<CalliopeService> {
        []
    }
    //servcies that are not strictly necessary
    var optionalServices : Set<CalliopeService> { [] }
    
    final var discoveredOptionalServices: Set<CalliopeService> = []
    
    lazy var requiredServicesUUIDs: Set<CBUUID> = Set(requiredServices.map { $0.uuid })

    lazy var optionalServicesUUIDs: Set<CBUUID> = Set(optionalServices.map { $0.uuid })
    
    var updateQueue = DispatchQueue.main
    
    
    let peripheral : CBPeripheral
    let name : String
    let servicesChangedCallback: () -> ()?
    
    required init?(peripheral: CBPeripheral, name: String, discoveredServices: Set<CalliopeService>, servicesToCharacteristicsMap: [CalliopeService:Set<CBUUID>], servicesChangedCallback: @escaping () -> ()?) {
        self.peripheral = peripheral
        self.name = name
        self.servicesChangedCallback = servicesChangedCallback
        super.init()
        
        
        self.discoveredOptionalServices = discoveredServices.intersection(optionalServices)
        if !FlashableCalliopeFactory.validateServicesAndCharacteristics(requiredServices: requiredServices, optionalServices: optionalServices, discoveredServices: discoveredServices, peripheral: peripheral, servicesToCharacteristicsMap: servicesToCharacteristicsMap) {
            LogNotify.log("failed to find required services or a way to activate them for \(String(describing: self))")
            return nil
        }
        LogNotify.log("successfully validated Calliope Type \(String(describing: self))")
    }

    var state : DiscoveredBLEDDevice.CalliopeBLEDeviceState = .usageReady {
        didSet {
            LogNotify.log("calliope state: \(state)")
            handleStateUpdate()
        }
    }

    func handleStateUpdate() {
        //default implementation does nothing
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
        servicesChangedCallback()
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
    
    func getCBCharacteristic(_ characteristic: CalliopeCharacteristic) -> CBCharacteristic? {
        guard state == .usageReady || state == .willReset,
            let serviceUuid = CalliopeBLEProfile.characteristicServiceMap[characteristic]?.uuid
            else { return nil }
        let uuid = characteristic.uuid
        return peripheral.services?.first { $0.uuid == serviceUuid }?
            .characteristics?.first { $0.uuid == uuid }
    }
    
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
}
