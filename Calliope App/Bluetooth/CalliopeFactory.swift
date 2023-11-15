//
//  CalliopeFactory.swift
//  Calliope App
//
//  Created by itestra on 13.11.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import Foundation
import CoreBluetooth

class FlashableCalliopeFactory{
    
    static let calliopeTypes = [CalliopeV3.self, CalliopeV1AndV2.self]
    
    static func getFlashableCalliopeForBLEDevice(device: DiscoveredBLEDDevice) -> FlashableCalliope? {
        let servicesChangedCallback = { [weak device] in device?.evaluateMode() }
        let calliope = calliopeTypes.compactMap { calliopeType in
            return calliopeType.init(peripheral: device.peripheral, name: device.name, discoveredServices: device.discoveredServices, servicesChangedCallback: servicesChangedCallback)
        }.first
        device.peripheral.delegate = calliope
        return calliope
    }
    
    static func validateOptionalAndRequiredServices(requiredServices: Set<CalliopeService>, optionalServices: Set<CalliopeService>, discoveredServices: Set<CalliopeService>, peripheral: CBPeripheral) -> Bool {
        LogNotify.log("start validating optional and required services")
        return validateRequiredServicesAndCharacteristics(requiredServices: requiredServices, optionalServices: optionalServices, discoveredServices: discoveredServices, peripheral: peripheral)
    }
    
    static func validateRequiredServicesAndCharacteristics(requiredServices: Set<CalliopeService>, optionalServices: Set<CalliopeService>, discoveredServices: Set<CalliopeService>, peripheral: CBPeripheral) -> Bool {
    
        var services = peripheral.services ?? []
        let uuidSet = Set(services.map { return $0.uuid })
        let requiredServicesUUIDs = Set(requiredServices.map { return $0.uuid })
        let optionalServicesUUIDs = Set(optionalServices.map { return $0.uuid })
        let discoveredOptionalServices = optionalServices.intersection(discoveredServices)
        var requiredServicesWithUndiscoveredCharacteristics = uuidSet.intersection(requiredServicesUUIDs.union(optionalServicesUUIDs))
        
        if requiredServices.isSubset(of: discoveredServices) {
            LogNotify.log("found all of \(requiredServicesUUIDs.count) required services:\n\(requiredServices)")
            LogNotify.log("found \(discoveredOptionalServices.count) of \(optionalServices.count) optional services")
            //TODO: Extend Validation to check for Characteristics
            //Some Charateristics checking is happening during the BLE Discovery Process
            //Add servicesWithUndiscoveredCharacteristics to input and check if required/optional Services are contained
            return true
        }
        return false
    }
}
