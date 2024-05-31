//
//  DataController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

class DataController {
    
    var availableSensors: [Sensor] = []
    
    
    var connectedCalliope: CalliopeAPI
    
    init(availableCharacteristics: [CalliopeService], connectedCalliope: CalliopeAPI) {
        availableSensors = availableCharacteristics.compactMap { key in
            return SensorUtility.serviceSensorMap[key]
        }
        self.connectedCalliope = connectedCalliope
        print(connectedCalliope.brightness)
        print(connectedCalliope.discoveredOptionalServices)
    }
    
}
