//
//  Sensor.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

class Sensor {
    
    var liveData: [Int] = []
    
    func startRecording() {
        // Notify Calliope
    }
    
    func stopRecording() {
        // Notify Calliope to stop sending
    }
    
    
    private func receiveData() {
        liveData.append(0)
    }
}
