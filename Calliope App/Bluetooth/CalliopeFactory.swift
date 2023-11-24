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
        let servicesChangedCallback = { [weak device] in 
            device?.usageReadyCalliope = nil
            //device?.evaluateMode()
        }
        let calliope = calliopeTypes.compactMap { calliopeType in
            return calliopeType.init(peripheral: device.peripheral, name: device.name, discoveredServices: device.discoveredServices, discoveredCharacteristicUUIDsForServiceUUID: device.serviceToDiscoveredCharacteristicsMap, servicesChangedCallback: servicesChangedCallback)
        }.first
        device.peripheral.delegate = calliope
        return calliope
    }
}
