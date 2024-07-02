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
        return apiCalliope?.discoveredOptionalServices.compactMap { key in
            return SensorUtility.serviceSensorMap[key]
        } ?? []
    }
    
    func sensorStartRecordingFor(chart : Chart, response: @escaping (Any) -> ()) {
        if self.availableSensors.contains(where: { compSensor in
            compSensor.calliopeService == chart.sensorType
        }) {
            if self.isRecording {
                self.sensorStopRecordingFor(chart: chart)
                return
            }
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let newValue = self.fetchValue(service: chart.sensorType)
                let parsedValue = DataParser.encode(data: newValue, service: chart.sensorType)
                Value.insertValue(value: parsedValue, chartsId: chart.id!)
                response(newValue)
            }
            self.isRecording = true
        }
    }
    
    func sensorStopRecordingFor(chart: Chart) {
        timer?.invalidate()
        if chart.sensorType == .uart {
            apiCalliope?.getTemperatureData = nil
        }
        isRecording = false
    }
    
    func fetchValue(service : CalliopeService) -> Any {
        asyncAndWait(on: DispatchQueue.global(qos: .userInitiated)) {
            switch service {
            case .accelerometer:
                let value = self.apiCalliope?.accelerometerValue ?? (0, 0, 0)
                return ((Double(value.0) / 1000), (Double(value.1) / 1000), (Double(value.2) / 1000))
            case .magnetometer:
                let value = self.apiCalliope?.magnetometerValue ?? (0, 0, 0)
                return (Double(value.0), Double(value.1), Double(value.2))
            case .temperature:
                return Double(self.apiCalliope?.temperature ?? 0)
            case .uart:
                if self.apiCalliope?.getTemperatureData == nil {
                    self.apiCalliope?.getTemperatureData = {value in self.value = value}
                }
                return Double(self.value ?? 0)
            default:
                return 0
            }
        }
    }
}
