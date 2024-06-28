//
//  Sensor.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import DGCharts

class Sensor {
    
    let calliopeService: CalliopeService
    let name: String
    
    
    init(calliopeService: CalliopeService, name: String) {
        self.calliopeService = calliopeService
        self.name = name
    }
}
