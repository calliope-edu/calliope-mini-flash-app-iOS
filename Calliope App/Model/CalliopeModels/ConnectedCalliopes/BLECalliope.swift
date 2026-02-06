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

class BLECalliope: Calliope, Jsonifiable {
    
    var adData: BluetoothAdvertisingData

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
    var getPrimaryServicesTM = WBTransactionManager<CBUUID?>()
    var getCharacteristicTM = WBTransactionManager<CharacteristicTransactionKey>()
    var getCharacteristicsTM = WBTransactionManager<CharacteristicsTransactionKey>()
    var readCharacteristicTM = WBTransactionManager<CharacteristicTransactionKey>()
    /*! @abstract Outstanding transactions for characteristic write requests */
    var writeCharacteristicTM = WBTransactionManager<CharacteristicTransactionKey>()
    
    // TODO: Set this correctly
    weak var view: WKWebView? = nil

    required init?(peripheral: CBPeripheral, name: String, discoveredServices: Set<CalliopeService>, discoveredCharacteristicUUIDsForServiceUUID: [CBUUID: Set<CBUUID>], servicesChangedCallback: @escaping () -> ()?, advertisementData: BluetoothAdvertisingData) {
        self.peripheral = peripheral
        self.name = name
        self.servicesChangedCallback = servicesChangedCallback
        self.adData = advertisementData
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
        self.writeCharacteristicTM.apply({
            if let err = error {
                $0.resolveAsFailure(withMessage: "Error writing characteristic: \(err.localizedDescription)")
                return
            }
            $0.resolveAsSuccess()
        },
            iff: {CharacteristicTransaction(
                transaction: $0
                )!.matchesCharacteristic(
                    characteristic
                )}
        )
        
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
        if self.readCharacteristicTM.transactions.count > 0 {
            // We have read transactions outstanding, which means that this is a response after a read request, so complete those transactions.
            self.readCharacteristicTM.apply({
                if let err = error {
                    $0.resolveAsFailure(withMessage: "Error reading characteristic: \(err.localizedDescription)")
                    return
                }
                $0.resolveAsSuccess(withObject: characteristic.value!)
            },
                iff: {CharacteristicTransaction(
                    transaction: $0
                )!.matchesCharacteristic(
                    characteristic
                )}
            )
        }
        else {
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
        
        // If we're doing notifications on the characteristic send them up.
        if characteristic.isNotifying {
            self.evaluateJavaScript(
                "receiveCharacteristicValueNotification(" +
                "'\(self.peripheral.identifier.uuidString)', " +
                "\(characteristic.uuid.uuidString.lowercased().jsonify()), " +
                "\(characteristic.value!.jsonify())" +
                ")")
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
    
    func jsonify() -> String {
        let props: [String: Any] = [
            "id": self.peripheral.identifier.uuidString,
            "name": (self.peripheral.name ?? NSNull()) as Any,
            "adData": self.adData.toDict(),
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
    
    func getPrimaryServices(transaction: WBTransaction) {
        guard let servicesTransaction = ServicesTransaction(transaction: transaction)
        else {
            transaction.resolveAsFailure(withMessage: "Invalid request")
            return
        }

        guard let services = self.peripheral.services else {
            self.getPrimaryServicesTM.addTransaction(transaction, atPath: servicesTransaction.serviceUUID)
            NSLog("Starting discovering for services on peripheral \(self.peripheral.name ?? "<unknown name>")")
            self.peripheral.discoverServices(nil)
            return
        }
        servicesTransaction.resolveFromServices(services)
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        var resolve: (WBTransaction) -> Void
        if let err = error {
            resolve = {
                $0.resolveAsFailure(withMessage: "An error occurred discovering services for the device: \(err)")
            }
        } else {
            resolve = {
                ServicesTransaction(transaction: $0)!.resolveFromServices(self.peripheral.services!)
            }
        }
        
        /* All outstanding requests for a primary service can be resolved. */
        if (self.getPrimaryServicesTM.transactions.count > 0) {
            self.getPrimaryServicesTM.apply(resolve)
        }
    }
    
    func getCharacteristic(transaction: WBTransaction) {
        guard
            let characteristicTransaction = CharacteristicTransaction(transaction: transaction)
        else {
            transaction.resolveAsFailure(withMessage: "Invalid message")
            return
        }

        guard let service = self.getService(withUUID: characteristicTransaction.serviceUUID)
        else {
            characteristicTransaction.resolveUnknownService()
            return
        }

        if let chars = service.characteristics {
            // Have already discovered characteristics for this device.
            if chars.contains(where: {$0.uuid == characteristicTransaction.characteristicUUID}) {
                transaction.resolveAsSuccess()
            } else {
                characteristicTransaction.resolveUnknownCharacteristic()
            }
            return
        }

        self.getCharacteristicTM.addTransaction(transaction, atPath: CharacteristicTransactionKey(serviceUUID: service.uuid, characteristicUUID: characteristicTransaction.characteristicUUID))
        NSLog("Start discovering characteristics for service \(service.uuid)")
        self.peripheral.discoverCharacteristics(nil, for: service)
    }
    
    private func getService(withUUID uuid: CBUUID) -> CBService?{
        guard
            let pservs = self.peripheral.services,
            let ind = pservs.firstIndex(where: {$0.uuid == uuid})
        else {
            return nil
        }
        return pservs[ind]
    }
    private func hasService(withUUID uuid: CBUUID) -> Bool {
        return self.getService(withUUID: uuid) != nil
    }
    
    func getCharacteristics(transaction: WBTransaction) {
        guard let characteristicsTransaction = CharacteristicsTransaction(transaction: transaction)
        else {
            transaction.resolveAsFailure(withMessage: "Invalid getCharacteristics message")
            return
        }

        guard let service = self.getService(withUUID: characteristicsTransaction.serviceUUID)
        else {
            characteristicsTransaction.resolveUnknownService()
            return
        }

        if let chars = service.characteristics {
            self.getCharacteristicsTM.apply({
                var characteristicUUIDs: [String] = []
                chars.forEach({ (characteristic) in
                    characteristicUUIDs.append(characteristic.uuid.uuidString)
                })
                $0.resolveAsSuccess(withObject: characteristicUUIDs)
            })
            
            return
        }

        self.getCharacteristicsTM.addTransaction(transaction, atPath: CharacteristicsTransactionKey(serviceUUID: characteristicsTransaction.serviceUUID))
        NSLog("Start discovering characteristics for service \(service.uuid)")
        self.peripheral.discoverCharacteristics(nil, for: service)
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        if let error_ = error {
            // speculative avoid crash judging by potential bug
            // in error as per https://forums.developer.apple.com/thread/84866
            NSLog("Error discovering characteristics: \(error_)")
            return
        }
        
        // Handle multiple characteristics
        if (self.getCharacteristicsTM.transactions.count > 0) {
            self.getCharacteristicsTM.apply({
                var characteristicUUIDs: [String] = []
                service.characteristics?.forEach({ (characteristic) in
                    characteristicUUIDs.append(characteristic.uuid.uuidString)
                })
                $0.resolveAsSuccess(withObject: characteristicUUIDs)
            },
            iff: { CharacteristicTransaction(transaction: $0)?.serviceUUID == service.uuid })
        }
        
        // Handle single characteristic
        if (self.getCharacteristicTM.transactions.count > 0) {
            self.getCharacteristicTM.apply({
                let transaction = CharacteristicTransaction(transaction: $0)!
                guard service.characteristics?.first(where: {$0.uuid == transaction.characteristicUUID}) != nil else {
                    transaction.resolveUnknownCharacteristic()
                    return
                }
                $0.resolveAsSuccess()
            },
            iff: {CharacteristicTransaction(transaction: $0)?.serviceUUID == service.uuid})
        }
    }
    
    func readCharacteristicValue(transaction: WBTransaction) {
        guard
            let characteristicTransaction = CharacteristicTransaction(transaction: transaction)
        else {
            transaction.resolveAsFailure(withMessage: "Invalid message")
            return
        }
        guard let service = self.getService(withUUID: characteristicTransaction.serviceUUID) else {
            characteristicTransaction.resolveUnknownService()
            return
        }
        guard let chars = service.characteristics else {
            transaction.resolveAsFailure(withMessage: "Characteristics have not yet been retrieved for service \(service.uuid.uuidString)")
            return
        }
        guard let char = chars.first(where: {$0.uuid == characteristicTransaction.characteristicUUID}) else {
            characteristicTransaction.resolveUnknownCharacteristic()
            return
        }

        self.readCharacteristicTM.addTransaction(transaction, atPath: CharacteristicTransactionKey(serviceUUID: characteristicTransaction.serviceUUID, characteristicUUID: characteristicTransaction.characteristicUUID))
        self.peripheral.readValue(for: char)
    }
    
    private func evaluateJavaScript(_ script: String) {
        guard let wv = self.view else {
            NSLog("Can't evaluate javascript as have no webview")
            return
        }
        wv.evaluateJavaScript(
            script,
            completionHandler: {
                _, error in
                if let err = error {
                    NSLog("Error evaluating \(script): \(err)")
                }
            }
        )
    }
    
    func writeCharacteristicValue(transaction: WBTransaction) {
        guard
            let transaction = WriteCharacteristicTransaction(transaction: transaction)
        else {
            transaction.resolveAsFailure(withMessage: "Invalid write characteristic message")
            return
        }

        guard
            let char = self.getCharacteristicObject(transaction.serviceUUID, uuid: transaction.characteristicUUID)
        else {
            transaction.resolveUnknownCharacteristic()
            return
        }

        self.writeCharacteristicValuetoDevice(char, transaction)
    }
    
    private func getCharacteristicObject(_ serviceUUID:CBUUID, uuid:CBUUID) -> CBCharacteristic? {
        if(self.peripheral.services == nil){
            return nil
        }
        var service:CBService? = nil
        for s in self.peripheral.services!{
            if(s.uuid == serviceUUID){
                service = s
                break
            }
        }
        
        guard let chars = service?.characteristics else {
            return nil
        }
        
        for char in chars{
            if(char.uuid == uuid){
                return char
            }
        }
        return nil
    }
    
    private func writeCharacteristicValuetoDevice(_ char: CBCharacteristic, _ transaction: WriteCharacteristicTransaction) {

        switch transaction.responseMode {
        case .required:
                guard char.properties.contains(.write) else {
                    transaction.transaction.resolveAsFailure(withMessage: "Write with response not supported")
                    return
                }

                self.peripheral.writeValue(transaction.data, for: char, type: .withResponse)
                self.writeCharacteristicTM.addTransaction(
                    transaction.transaction,
                    atPath: CharacteristicTransactionKey(
                        serviceUUID: transaction.serviceUUID, characteristicUUID: transaction.characteristicUUID
                    )
                )
        case .never:
                guard char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse)
                else {
                    transaction.transaction.resolveAsFailure(
                        withMessage: "Characteristic does not support writing"
                    )
                    return
                }
                self.peripheral.writeValue(transaction.data, for: char, type: .withoutResponse)
                transaction.transaction.resolveAsSuccess()
        case .optional:
            // optional is in fact deprecated and the instructions are "Use any combination of the
            // sub procedures" in webbluetoothcg.github.io/web-bluetooth/#writecharacteristicvalue
            // so we do a write with response if possible else without.
            if char.properties.contains(.write) {
                self.peripheral.writeValue(transaction.data, for: char, type: .withResponse)
                self.writeCharacteristicTM.addTransaction(
                    transaction.transaction,
                    atPath: CharacteristicTransactionKey(
                        serviceUUID: transaction.serviceUUID, characteristicUUID: transaction.characteristicUUID
                    )
                )
            } else if char.properties.contains(.writeWithoutResponse) {
                self.peripheral.writeValue(transaction.data, for: char, type: .withoutResponse)
                transaction.transaction.resolveAsSuccess()
            } else {
                transaction.transaction.resolveAsFailure(withMessage: "Characteristic does not support writing")
            }
        }
    }
    
    func startNotifications(transaction: WBTransaction) {
        guard let characteristicTransaction = CharacteristicTransaction(transaction: transaction) else {
            transaction.resolveAsFailure(withMessage: "Invalid start notifications message")
            return
        }

        guard let char = self.getCharacteristicObject(characteristicTransaction.serviceUUID, uuid: characteristicTransaction.characteristicUUID) else {
            characteristicTransaction.resolveUnknownCharacteristic()
            return
        }
        NSLog("Starting notifications for characteristic \(characteristicTransaction.characteristicUUID.uuidString) on device \(self.peripheral.name ?? "<no-name>")")

        self.peripheral.setNotifyValue(true, for: char)
        transaction.resolveAsSuccess()
    }
    
    func stopNotifications(transaction: WBTransaction) {
        guard let characteristicTransaction = CharacteristicTransaction(transaction: transaction) else {
            transaction.resolveAsFailure(withMessage: "Invalid start notifications message")
            return
        }

        guard let char = self.getCharacteristicObject(characteristicTransaction.serviceUUID, uuid: characteristicTransaction.characteristicUUID) else {
            characteristicTransaction.resolveUnknownCharacteristic()
            return
        }
        NSLog("Stopping notifications for characteristic \(characteristicTransaction.characteristicUUID.uuidString) on device \(self.peripheral.name ?? "<no-name>")")

        self.peripheral.setNotifyValue(false, for: char)
        transaction.resolveAsSuccess()
    }
}
