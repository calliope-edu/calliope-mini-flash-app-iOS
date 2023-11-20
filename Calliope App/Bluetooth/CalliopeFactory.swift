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
            return calliopeType.init(peripheral: device.peripheral, name: device.name, discoveredServices: device.discoveredServices, servicesToCharacteristicsMap: device.serviceToDiscoveredCharacteristicsMap, servicesChangedCallback: servicesChangedCallback)
        }.first
        device.peripheral.delegate = calliope
        return calliope
    }
    
    static func validateServicesAndCharacteristics(requiredServices: Set<CalliopeService>, optionalServices: Set<CalliopeService>, discoveredServices: Set<CalliopeService>, peripheral: CBPeripheral, servicesToCharacteristicsMap: [CalliopeService:Set<CBUUID>]) -> Bool {
        LogNotify.log("start validating optional and required services")
        //Validate Services, are required Services discovered
        let requiredServicesUUIDs = Set(requiredServices.map { return $0.uuid })
        let discoveredOptionalServices = optionalServices.intersection(discoveredServices)
        
        if requiredServices.isSubset(of: discoveredServices) {
            LogNotify.log("found all of \(requiredServicesUUIDs.count) required services:\n\(requiredServices)")
            LogNotify.log("found \(discoveredOptionalServices.count) of \(optionalServices.count) optional services")
            
            //Validate Characteristics, are characteristics discovered for all optional and required services
            for service in discoveredServices.intersection(requiredServices.union(optionalServices)) {
                guard let foundCharacteristic = servicesToCharacteristicsMap[service] else {
                    return false
                }
                LogNotify.log("Characteristics \(foundCharacteristic) found for service \(service.uuid)")
            }
        
            return true
        }
        return false
    }
}
