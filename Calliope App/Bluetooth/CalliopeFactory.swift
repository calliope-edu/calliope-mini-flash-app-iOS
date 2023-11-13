//
//  CalliopeFactory.swift
//  Calliope App
//
//  Created by itestra on 13.11.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import Foundation
import CoreBluetooth

class FlashableCalliopeBuilder{
    
    static func getFlashableCalliopeForBLEDevice(device: DiscoveredBLEDDevice) -> FlashableCalliope {
        let servicesChangedCallback = { [weak device] in device?.evaluateMode() }
        if device.discoveredServices.contains(.secure_dfu) {
            return CalliopeV3(peripheral: device.peripheral, name: device.name, servicesChangedCallback: servicesChangedCallback)
        } else {
            return CalliopeV1AndV2(peripheral: device.peripheral, name: device.name, servicesChangedCallback: servicesChangedCallback)
        }
    }
    
    func validateOptionalAndRequiredServices(device: DiscoveredBLEDDevice, type: FlashableCalliope) {
        LogNotify.log("Validate the Required and Optional Services here")
    }
}
