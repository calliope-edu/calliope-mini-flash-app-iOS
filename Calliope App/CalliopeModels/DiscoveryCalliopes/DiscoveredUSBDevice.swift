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
    
    init?(url: URL, name: String) {
        self.url = url
        super.init(name: name)
        if !validateCalliope(url: url) {
            return nil
        }
       
    }
    
    func validateCalliope(url: URL) -> Bool {
        let pathComponent = url.appendingPathComponent("DETAILS.TXT")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        let isAccessing = url.startAccessingSecurityScopedResource()
        
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return fileManager.fileExists(atPath: filePath)
    }
}
