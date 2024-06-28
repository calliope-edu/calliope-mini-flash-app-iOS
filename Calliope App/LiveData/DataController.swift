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
    var apiCalliope: CalliopeAPI?
    var isRecording = false
    var timer : Timer?
    
    var value: Int?
    
    init() {
        guard let connectedCalliope = MatrixConnectionViewController.instance.usageReadyCalliope else {
           return
        }
        self.apiCalliope = connectedCalliope as? CalliopeAPI
        self.availableSensors = apiCalliope?.discoveredOptionalServices.compactMap { key in
            return SensorUtility.serviceSensorMap[key]
        } ?? []
    }
    
    func getAvailableSensors() -> [Sensor] {
        return availableSensors
    }
    
    func sensorStartRecording(sensor : Sensor, response: @escaping (Int) -> ()) {
        if self.availableSensors.contains(where: { compSensor in
            compSensor.calliopeService == sensor.calliopeService
        }) {
            if self.isRecording {
                self.sensorStopRecording(sensor: sensor)
                return
            }
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let newValue = self.getValue(sensor: sensor)
                response(newValue)
            }
            
            self.isRecording = true
        }
    }
    
    func sensorStopRecording(sensor: Sensor?) {
        timer?.invalidate()
        if let sensor = sensor, sensor.calliopeService == .uart {
            apiCalliope?.getTemperatureData = nil
        }
        isRecording = false
    }
    
    func getValue(sensor : Sensor) -> Int {
        asyncAndWait(on: DispatchQueue.global(qos: .userInitiated)) {
            switch sensor.calliopeService {
            case .accelerometer:
                return Int(self.apiCalliope?.accelerometerValue!.0 ?? 0)
            case .temperature:
                return Int(self.apiCalliope?.temperature ?? 0)
            case .uart:
                if self.apiCalliope?.getTemperatureData == nil {
                    self.apiCalliope?.getTemperatureData = {value in self.value = value}
                }
                return self.value ?? 0
            default:
                return Int(1)
            }
        }
    }
}
