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
import WebKit

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
    var wbNotifications: [CalliopeCharacteristic: (String, String, String) -> Void] // This allows the WBMessageHandler to subscribe to notifications via the extension of this class
    
    required init?(peripheral: CBPeripheral, name: String, discoveredServices: Set<CalliopeService>, discoveredCharacteristicUUIDsForServiceUUID: [CBUUID: Set<CBUUID>], servicesChangedCallback: @escaping () -> ()?) {
        self.peripheral = peripheral
        self.name = name
        self.servicesChangedCallback = servicesChangedCallback
        self.wbNotifications = [:]
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
    let bleOperationsQueue = DispatchQueue(label: "bleOperationsQueue")
    var bleOperationsGroup: DispatchGroup? = nil
    
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
        
        handleValueUpdate(calliopeCharacteristic, value)
       
        // notifying a possible WBWebView that started notifications on this characteristic
        if let calliopeCharacteristic = CalliopeCharacteristic(rawValue: characteristic.uuid.uuidString), let callback = wbNotifications[calliopeCharacteristic] {
            callback(peripheral.identifier.uuidString, characteristic.uuid.uuidString, value.jsonify())
        }
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
    
    private func explicitWriteResponse(_ error: Error?) {
        writingCharacteristic = nil
        //set potential error and move on
        writeError = error
        if let error = error {
            LogNotify.log("received error from writing: \(error)")
        } else {
            LogNotify.log("received write success message")
        }
        bleOperationsGroup?.leave()
    }
    
    private func explicitSetNotifyResponse(_ error: Error?) {
        notifyingCharacteristic = nil
        //set potential error and move on
        setNotifyError = error
        if let error = error {
            LogNotify.log("received error from writing: \(error)")
        } else {
            LogNotify.log("received set notify success message")
        }
        bleOperationsGroup?.leave()
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
        bleOperationsGroup?.leave()
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
        try bleOperationsQueue.sync {
            writingCharacteristic = characteristic
            
            self.bleOperationsGroup = DispatchGroup()
            self.bleOperationsGroup!.enter()
            self.peripheral.writeValue(data, for: characteristic, type: .withResponse)
            
            if self.bleOperationsGroup!.wait(timeout: DispatchTime.now() + BluetoothConstants.writeTimeout) == .timedOut {
                LogNotify.log("write to \(characteristic) timed out")
                self.writeError = CBError(.connectionTimeout)
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
        return try bleOperationsQueue.sync {
            readingCharacteristic = characteristic
            
            self.bleOperationsGroup = DispatchGroup()
            self.bleOperationsGroup!.enter()
            self.peripheral.readValue(for: characteristic)
            if self.bleOperationsGroup!.wait(timeout: DispatchTime.now() + BluetoothConstants.readTimeout) == .timedOut {
                LogNotify.log("read from \(characteristic) timed out")
                self.readError = CBError(.connectionTimeout)
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
        try bleOperationsQueue.sync{
            notifyingCharacteristic = characteristic
            
            self.bleOperationsGroup = DispatchGroup()
            self.bleOperationsGroup!.enter()
            self.peripheral.setNotifyValue(activate, for: characteristic)
            
            if self.bleOperationsGroup!.wait(timeout: DispatchTime.now() + BluetoothConstants.readTimeout) == .timedOut {
                LogNotify.log("activate notifications from \(characteristic) timed out")
                self.setNotifyError = CBError(.connectionTimeout)
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

// Extension with the API used by the WBMessageHandler
extension BLECalliope: Jsonifiable {
    func getPrimaryServices(transaction: WBTransaction) {
        guard let servicesTransaction = ServicesTransaction(transaction: transaction)
        else {
            transaction.resolveAsFailure(withMessage: "Invalid request")
            return
        }
        
        if let services = getKnownCalliopeServices() {
            servicesTransaction.resolveFromServices(services)
        }
        else {
            transaction.resolveAsFailure(withMessage: "Could not get services.")
        }
    }
    
    func getCharacteristic(transaction: WBTransaction) {
        guard let characteristicTransaction = CharacteristicTransaction(transaction: transaction) else {
            transaction.resolveAsFailure(withMessage: "Invalid message")
            return
        }
        
        if let characteristic = getKnownCalliopeCharactersitic(serviceUUID: characteristicTransaction.serviceUUID, characteristicUUID: characteristicTransaction.characteristicUUID) {
            transaction.resolveAsSuccess()
        }
        else {
            characteristicTransaction.resolveUnknownCharacteristic()
        }
    }
    
    func getCharacteristics(transaction: WBTransaction) {
        guard let characteristicsTransaction = CharacteristicsTransaction(transaction: transaction) else {
            transaction.resolveAsFailure(withMessage: "Invalid getCharacteristics message")
            return
        }
        
        if let characteristics = getKnownCalliopeCharacteristics(withUUID: characteristicsTransaction.serviceUUID) {
            let characteristicUUIDs = characteristics.map{ characteristic in
                characteristic.uuid.uuidString
            }
            transaction.resolveAsSuccess(withObject: characteristicUUIDs)
        }
        else {
            transaction.resolveAsFailure(withMessage: "Could not get characteristics.")
        }
   }
    
    func readCharacteristicValue(transaction: WBTransaction) {
        guard let characteristicTransaction = CharacteristicTransaction(transaction: transaction) else {
            transaction.resolveAsFailure(withMessage: "Invalid message")
            return
        }
        
        guard let characteristic = getKnownCalliopeCharactersitic(serviceUUID: characteristicTransaction.serviceUUID, characteristicUUID: characteristicTransaction.characteristicUUID) else {
            characteristicTransaction.resolveUnknownCharacteristic()
            return
        }
        
        let result = try? self.read(characteristic: characteristic)
        if result == nil {
            transaction.resolveAsFailure(withMessage: "Could not read characteristic \(characteristic.uuid.uuidString)")
        }
        else {
            transaction.resolveAsSuccess(withObject: result!)
        }
    }
    
    func writeCharacteristicValue(transaction: WBTransaction) {
        guard let writeCharacteristicTransaction = WriteCharacteristicTransaction(transaction: transaction) else {
            transaction.resolveAsFailure(withMessage: "Invalid write characteristic message")
            return
        }
        
        guard let characteristic = getKnownCalliopeCharactersitic(serviceUUID: writeCharacteristicTransaction.serviceUUID, characteristicUUID: writeCharacteristicTransaction.characteristicUUID) else {
            writeCharacteristicTransaction.resolveUnknownCharacteristic()
            return
        }
        
        self.writeCharacteristicValuetoDevice(characteristic, writeCharacteristicTransaction)
    }
    
    private func writeCharacteristicValuetoDevice(_ char: CBCharacteristic, _ transaction: WriteCharacteristicTransaction) {
        
        switch transaction.responseMode {
        case .required:
            guard char.properties.contains(.write) else {
                transaction.transaction.resolveAsFailure(withMessage: "Write with response not supported")
                return
            }
            
            do {
                try self.write(transaction.data, for: char)
            }
            catch {
                transaction.transaction.resolveAsFailure(withMessage: "Write to characteristic \(char.uuid.uuidString) failed")
                return
            }
            transaction.transaction.resolveAsSuccess()
        case .never:
            guard char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse)
            else {
                transaction.transaction.resolveAsFailure(
                    withMessage: "Characteristic does not support writing"
                )
                return
            }
            if let calliopeCharacteristic = CalliopeCharacteristic(rawValue: char.uuid.uuidString) {
                do {
                    try self.writeWithoutResponse(transaction.data, for: calliopeCharacteristic)
                }
                catch {
                    transaction.transaction.resolveAsFailure(withMessage: "Write to characteristic \(char.uuid.uuidString) failed")
                    return
                }
                transaction.transaction.resolveAsSuccess()
            }
            else {
                transaction.transaction.resolveAsFailure(withMessage: "Characteristic \(char.uuid.uuidString) is not a known Calliope Characteristic")
            }
        case .optional:
            // optional is in fact deprecated and the instructions are "Use any combination of the
            // sub procedures" in webbluetoothcg.github.io/web-bluetooth/#writecharacteristicvalue
            // so we do a write with response if possible else without.
            if char.properties.contains(.write) {
                do {
                    try self.write(transaction.data, for: char)
                }
                catch {
                    transaction.transaction.resolveAsFailure(withMessage: "Write to characteristic \(char.uuid.uuidString) failed")
                    return
                }
                transaction.transaction.resolveAsSuccess()
            } else if char.properties.contains(.writeWithoutResponse) {
                if let calliopeCharacteristic = CalliopeCharacteristic(rawValue: char.uuid.uuidString) {
                    do {
                        try self.writeWithoutResponse(transaction.data, for: calliopeCharacteristic)
                    }
                    catch {
                        transaction.transaction.resolveAsFailure(withMessage: "Write to characteristic \(char.uuid.uuidString) failed")
                        return
                    }
                    transaction.transaction.resolveAsSuccess()
                }
                else {
                    transaction.transaction.resolveAsFailure(withMessage: "Characteristic \(char.uuid.uuidString) is not a known Calliope Characteristic")
                }
            } else {
                transaction.transaction.resolveAsFailure(withMessage: "Characteristic does not support writing")
            }
        }
    }
    
    func startNotifications(transaction: WBTransaction, onNotificationCallback: @escaping (String, String, String) -> Void) {
        guard let characteristicTransaction = CharacteristicTransaction(transaction: transaction) else {
            transaction.resolveAsFailure(withMessage: "Invalid start notifications message")
            return
        }
        
        guard let characteristic = self.getKnownCalliopeCharactersitic(serviceUUID: characteristicTransaction.serviceUUID, characteristicUUID: characteristicTransaction.characteristicUUID) else {
            characteristicTransaction.resolveUnknownCharacteristic()
            return
        }
        
        LogNotify.log("Starting notifications for characteristic \(characteristicTransaction.characteristicUUID.uuidString) on device \(self.peripheral.name ?? "<no-name>")")
        
        if let calliopeCharacteristic = CalliopeCharacteristic(rawValue: characteristic.uuid.uuidString) {
            do {
                try self.setNotify(characteristic: characteristic, true)
            }
            catch {
                transaction.resolveAsFailure(withMessage: "Starting notifications for characteristic \(characteristic.uuid.uuidString) failed")
                return
            }
            wbNotifications[calliopeCharacteristic] = onNotificationCallback
            transaction.resolveAsSuccess()
        }
        else {
            transaction.resolveAsFailure(withMessage: "Characteristic \(characteristic.uuid.uuidString) is not a known Calliope Characteristic")
        }
    }
    
    func stopNotifications(transaction: WBTransaction) {
        guard let characteristicTransaction = CharacteristicTransaction(transaction: transaction) else {
            transaction.resolveAsFailure(withMessage: "Invalid start notifications message")
            return
        }
        
        guard let characteristic = self.getKnownCalliopeCharactersitic(serviceUUID: characteristicTransaction.serviceUUID, characteristicUUID: characteristicTransaction.characteristicUUID) else {
            characteristicTransaction.resolveUnknownCharacteristic()
            return
        }
        
        LogNotify.log("Stopping notifications for characteristic \(characteristicTransaction.characteristicUUID.uuidString) on device \(self.peripheral.name ?? "<no-name>")")
        
        if let calliopeCharacteristic = CalliopeCharacteristic(rawValue: characteristic.uuid.uuidString) {
            do {
                try self.setNotify(characteristic: characteristic, false)
            }
            catch {
                transaction.resolveAsFailure(withMessage: "Stopping notifications for characteristic \(characteristic.uuid.uuidString) failed")
                return
            }
            wbNotifications[calliopeCharacteristic] = nil
            transaction.resolveAsSuccess()
        }
        else {
            transaction.resolveAsFailure(withMessage: "Characteristic \(characteristic.uuid.uuidString) is not a known Calliope Characteristic")
        }
    }
    
    private func getKnownCalliopeServices() -> [CBService]? {
        guard let services = self.peripheral.services else {
            LogNotify.log("Expected for services to already be discovered. This should not happen.")
            return nil
        }
        
        let knownCalliopeServices = services.filter {
            CalliopeService(rawValue: $0.uuid.uuidString) != nil
        }
        
        return knownCalliopeServices
    }
    
    private func getKownCalliopeService(withUUID uuid: CBUUID) -> CBService?{
        guard let services = getKnownCalliopeServices() else {
            return nil
        }
        
        guard let index = services.firstIndex(where: {$0.uuid == uuid}) else {
            return nil
        }
        
        return services[index]
    }
    
    private func getKnownCalliopeCharacteristics(withUUID uuid: CBUUID) -> [CBCharacteristic]? {
        guard let service = getKownCalliopeService(withUUID: uuid) else {
            return nil
        }
        
        guard let characteristics = service.characteristics else {
            LogNotify.log("Characteristics have not yet been retrieved for service \(service.uuid.uuidString)")
            return nil
        }
        
        let knownCalliopeCharacteristics = characteristics.filter {
            CalliopeCharacteristic(rawValue: $0.uuid.uuidString) != nil
        }
        
        return knownCalliopeCharacteristics
    }
    
    private func getKnownCalliopeCharactersitic(serviceUUID: CBUUID, characteristicUUID: CBUUID) -> CBCharacteristic? {
        guard let characteristics = getKnownCalliopeCharacteristics(withUUID: serviceUUID) else {
            return nil
        }
        
        guard let index = characteristics.firstIndex(where: {$0.uuid == characteristicUUID}) else {
            return nil
        }
        
        return characteristics[index]
    }
    
    func jsonify() -> String {
        let props: [String: Any] = [
            "id": self.peripheral.identifier.uuidString,
            "name": (self.peripheral.name ?? NSNull()) as Any,
            "deviceClass": 0,
            "vendorIDSource": 0,
            "vendorID": 0,
            "productID": 0,
            "productVersion": 0,
            "uuids": [] as [String],
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: props)
            return String(data: jsonData, encoding: String.Encoding.utf8)!
        } catch let error {
            assert(false, "error converting to json: \(error)")
            return ""
        }
    }
}
