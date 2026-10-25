//
//  DiscoveredUSBCalliope.swift
//  Calliope App
//
//  Created by itestra on 01.02.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

class DiscoveredUSBDevice: DiscoveredDevice {
    let destination: USBDestination

    init(name: String, destination: USBDestination) {
        self.destination = destination
        super.init(name: name)
    }
}
