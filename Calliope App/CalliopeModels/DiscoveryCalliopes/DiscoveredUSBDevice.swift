//
//  DiscoveredUSBCalliope.swift
//  Calliope App
//
//  Created by itestra on 01.02.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

class DiscoveredUSBDevice: DiscoveredDevice {
    let url: URL
    
    init(url: URL, name: String) {
        self.url = url
        super.init(name: name)
    }
}
