//
//  Network.swift
//  Calliope App
//
//  Created by itestra on 05.12.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import Foundation
import Network

class Network {
    
    var networkAvailable: Bool = false
    
    required init() {
        startNetworkDiscovery()
    }
    
    private func startNetworkDiscovery(){
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                self.networkAvailable = true
                // Perform actions when internet is available
            } else {
                self.networkAvailable = false
                // Perform actions when internet is not available
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    public func isNetworkAvailable() -> Bool {
        return networkAvailable
    }
}
