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
    let bleOperationsQueue = DispatchQueue(label: "com.yourapp.bluetooth.operations")
    var bleOperationsGroup: DispatchGroup? = nil
    var bleError: Error? = nil
    var operationCharacteristic: CBCharacteristic? = nil
    var bleResultValue: Data? = nil
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let writingCharacteristic = operationCharacteristic, characteristic.uuid == writingCharacteristic.uuid {
            operationCharacteristic = nil
            //set potential error and move on
            bleError = error
            if let error = error {
                LogNotify.log("received error from writing: \(error)")
            } else {
                LogNotify.log("received write success message")
            }
            bleOperationsGroup?.leave()
            return
        } else {
            LogNotify.log("didWrite called for characteristic \(characteristic) that we did not write to!")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        LogNotify.log("Calliope \(peripheral.name ?? "[no name]") invalidated services \(invalidatedServices). Re-evaluate mode.")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.servicesChangedCallback()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let readingCharac = operationCharacteristic, characteristic.uuid == readingCharac.uuid {
            explicitReadResponse(for: characteristic, error: error)
            return
        }
        
        guard error == nil, let value = characteristic.value else {
            LogNotify.log(bleError?.localizedDescription ?? "characteristic \(characteristic.uuid) does not have a value")
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
        if let writingCharacteristic = operationCharacteristic, characteristic.uuid == writingCharacteristic.uuid {
            explicitSetNotifyResponse(error)
            return
        } else {
            LogNotify.log("updated notification state for for characteristic \(characteristic) that we did not subscribe to!")
        }
    }
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        // Post notification for flow control in partial flashing
        NotificationCenter.default.post(
            name: .bleBufferReadyForPeripheral,
            object: peripheral
        )
    }

    func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {
        LogNotify.log("value for \(characteristic) updated (\(value.hexEncodedString()))")
    }
    
    private func explicitSetNotifyResponse(_ error: Error?) {
        operationCharacteristic = nil
        //set potential error and move on
        bleError = error
        if let error = error {
            LogNotify.log("received error from writing: \(error)")
        } else {
            LogNotify.log("received set notify success message")
        }
        bleOperationsGroup?.leave()
    }
    
    private func explicitReadResponse(for characteristic: CBCharacteristic, error: Error?) {
        operationCharacteristic = nil
        //answer to explicit read request
        if let error = error {
            LogNotify.log("received error from reading \(characteristic): \(error)")
            bleError = error
            LogNotify.log(error.localizedDescription)
        } else {
            bleResultValue =  characteristic.value
            LogNotify.log("received read response from \(characteristic): \(String(describing: bleResultValue?.hexEncodedString()))")
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
    
    func write(_ data: Data, for characteristic: CalliopeCharacteristic, _ completion: @escaping (Result<Void, Error>) -> Void) throws {
        let cbCharacteristic = try checkWritePreconditions(for: characteristic)
        write(data, for: cbCharacteristic, completion)
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
    
    func write(_ data: Data, for characteristic: CBCharacteristic,_ completion: @escaping (Result<Void, Error>) -> Void) {
        executeBLEOperation(characteristic: characteristic, operation: {
            self.peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }, timeout: BluetoothConstants.writeTimeout, completion: {
            result in
            switch(result) {
            case .success():
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }, type: OperationType.write)
    }
    
    
    func read(characteristic: CalliopeCharacteristic, _ completion: @escaping (Result<Data, Error>) -> Void) throws {
        guard let cbCharacteristic = getCBCharacteristic(characteristic)
        else {
            throw "no service that contains characteristic \(characteristic)"
        }
        read(characteristic: cbCharacteristic, completion)
    }
    
    func read(characteristic: CBCharacteristic, _ completion: @escaping (Result<Data, Error>) -> Void) {
        executeBLEOperation(characteristic: characteristic, operation: {
            self.peripheral.readValue(for: characteristic)
        }, timeout: BluetoothConstants.readTimeout, completion: {
            result in
            switch(result) {
            case .success():
                let data = self.bleResultValue
                self.bleResultValue = nil
                if(data != nil) {
                    completion(.success(data!))
                }
                else {
                    completion(.failure(OperationError.dataMissing("Did not get any data.")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }, type: OperationType.read)
    }
    
    func setNotify(characteristic: CalliopeCharacteristic, _ activate: Bool) throws {
        guard let cbCharacteristic = getCBCharacteristic(characteristic)
        else {
            throw "no service that contains characteristic \(characteristic)"
        }
        return setNotify(characteristic: cbCharacteristic, activate, nil)
    }
    
    func setNotify(characteristic: CBCharacteristic, _ activate: Bool, _ completion: ((Result<Void, Error>) -> Void)?) {
        executeBLEOperation(characteristic: characteristic, operation: {
            self.peripheral.setNotifyValue(activate, for: characteristic)
        }, timeout: BluetoothConstants.readTimeout, completion: {
           result in
            switch(result) {
            case .success():
                completion?(.success(()))
            case .failure(let error):
                completion?(.failure(error))
            }
        }, type: OperationType.setNotify)
    }
    
    enum OperationType: String {
        case read = "Read"
        case write = "Write"
        case setNotify = "Set Notify"
    }
    
    enum OperationError: Error {
        case dataMissing(String)
    }
    
    private func executeBLEOperation(characteristic: CBCharacteristic, operation: @escaping () -> Void, timeout: Double, completion: @escaping (Result<Void, Error>) -> Void, type: OperationType) {
        bleOperationsQueue.async {
            self.operationCharacteristic = characteristic
            
            self.bleOperationsGroup = DispatchGroup()
            self.bleOperationsGroup!.enter()
            
            operation()
            
            if self.bleOperationsGroup!.wait(timeout: DispatchTime.now() + timeout) == .timedOut {
                self.bleError = CBError(.connectionTimeout)
            }
            
            guard self.bleError == nil else {
                let error = self.bleError!
                self.bleError = nil
                LogNotify.log("\(type.rawValue) of \(characteristic) failed with error: \(error)", level: LogNotify.LEVEL.ERROR)
                completion(.failure(error))
                return
            }
            
            LogNotify.log("\(type.rawValue) of \(characteristic) successfull")
            completion(.success(()))
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
        
        if getKnownCalliopeCharactersitic(serviceUUID: characteristicTransaction.serviceUUID, characteristicUUID: characteristicTransaction.characteristicUUID) != nil {
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
        
        self.read(characteristic: characteristic, {
            result in
            switch(result) {
            case .success(let data):
                transaction.resolveAsSuccess(withObject: data)
            case .failure(let error):
                transaction.resolveAsFailure(withMessage: "Read resulted in error: \(error)")
            }
        })
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
        
        switch writeCharacteristicTransaction.responseMode {
        case .required:
           writeTransactionWithResponse(characteristic: characteristic, transaction: writeCharacteristicTransaction)
        case .never:
            writeTransactionWithoutResponse(characteristic: characteristic, transaction: writeCharacteristicTransaction)
       case .optional:
            // optional is in fact deprecated and the instructions are "Use any combination of the
            // sub procedures" in webbluetoothcg.github.io/web-bluetooth/#writecharacteristicvalue
            // so we do a write with response if possible else without.
            if characteristic.properties.contains(.write) {
                writeTransactionWithResponse(characteristic: characteristic, transaction: writeCharacteristicTransaction)
            } else if characteristic.properties.contains(.writeWithoutResponse) {
                writeTransactionWithoutResponse(characteristic: characteristic, transaction: writeCharacteristicTransaction)
            } else {
                writeCharacteristicTransaction.transaction.resolveAsFailure(withMessage: "Characteristic does not support writing")
            }
        }
    }
    
    private func writeTransactionWithResponse(characteristic: CBCharacteristic, transaction: WriteCharacteristicTransaction) {
        guard characteristic.properties.contains(.write) else {
            transaction.transaction.resolveAsFailure(withMessage: "Write with response not supported")
            return
        }
        
        self.write(transaction.data, for: characteristic, { result in
            switch(result) {
            case .success():
                transaction.transaction.resolveAsSuccess()
            case .failure(let error):
                transaction.transaction.resolveAsFailure(withMessage: "Write to characteristic \(characteristic.uuid.uuidString) failed with error \(error)")
            }
       })
    }
    
    private func writeTransactionWithoutResponse(characteristic: CBCharacteristic, transaction: WriteCharacteristicTransaction) {
        guard characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) else {
            transaction.transaction.resolveAsFailure(withMessage: "Characteristic does not support writing"            )
            return
        }
        
        if let calliopeCharacteristic = CalliopeCharacteristic(rawValue: characteristic.uuid.uuidString) {
            do {
                try self.writeWithoutResponse(transaction.data, for: calliopeCharacteristic)
            }
            catch {
                transaction.transaction.resolveAsFailure(withMessage: "Write to characteristic \(characteristic.uuid.uuidString) failed")
                return
            }
            transaction.transaction.resolveAsSuccess()
        }
        else {
            transaction.transaction.resolveAsFailure(withMessage: "Characteristic \(characteristic.uuid.uuidString) is not a known Calliope Characteristic")
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
            self.setNotify(characteristic: characteristic, true, {
                result in
                switch(result) {
                case .success():
                    break
                case .failure(let error):
                    transaction.resolveAsFailure(withMessage: "Starting notifications for characteristic \(characteristic.uuid.uuidString) failed with error: \(error)")
                }
            })
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
            self.setNotify(characteristic: characteristic, false, {
                result in
                switch(result) {
                case .success():
                    break
                case .failure(let error):
                    transaction.resolveAsFailure(withMessage: "Starting notifications for characteristic \(characteristic.uuid.uuidString) failed with error: \(error)")
                }
            })
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

// MARK: - Notification Names
extension Notification.Name {
    /// Posted when peripheral is ready to send more data without response (BLE flow control)
    static let bleBufferReadyForPeripheral = Notification.Name("bleBufferReadyForPeripheral")
}
