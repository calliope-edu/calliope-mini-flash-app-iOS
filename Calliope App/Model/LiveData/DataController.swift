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
    static var activeServices: [CalliopeService] = []
    var apiCalliope: CalliopeAPI?
    var isRecording = false
    var timer : Timer?
    
    var value: Any?
    
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
        apiCalliope = MatrixConnectionViewController.instance.usageReadyCalliope as? CalliopeAPI
        return apiCalliope?.discoveredOptionalServices.compactMap { key in
            return SensorUtility.serviceSensorMap[key]
        } ?? []
    }
    
    func sensorStartRecordingFor(chart : Chart, response: @escaping ((String, Double, Double)) -> ()) {
        if DataController.activeServices.contains(chart.sensorType) {
            return
        }
        if self.getAvailableSensors().contains(where: { compSensor in
            compSensor.calliopeService == chart.sensorType
        }) {
            if self.isRecording {
                self.sensorStopRecordingFor(chart: chart)
                return
            }
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let newValue = self.fetchValue(service: chart.sensorType)
                for (axis, time, value) in newValue {
                    let parsedValue = DataParser.encode(data: [axis : value], service: chart.sensorType)
                    Value.insertValue(value: parsedValue, chartsId: chart.id!)
                    response((axis, time, value))
                }
            }
            self.isRecording = true
            DataController.activeServices.append(chart.sensorType)
        }
    }
    
    func sensorStopRecordingFor(chart: Chart) {
        timer?.invalidate()
        if chart.sensorType == .uart {
            apiCalliope?.uartValueNotification = nil
        }
        isRecording = false
        _ = DataController.activeServices.remove(object: chart.sensorType)
    }
    
    func fetchValue(service : CalliopeService) -> [(String, Double, Double)] {
        asyncAndWait(on: DispatchQueue.global(qos: .userInitiated)) {
            let timestamp = (Date().timeIntervalSinceReferenceDate * 100).rounded(toPlaces: 0)
            switch service {
            case .accelerometer:
                let value = self.apiCalliope?.accelerometerValue ?? (0, 0, 0)
                return [
                    ("X", timestamp, Double(value.0)),
                    ("Y", timestamp, Double(value.1)),
                    ("Z", timestamp, Double(value.2))
                ]
            case .magnetometer:
                let value = self.apiCalliope?.magnetometerValue ?? (0, 0, 0)
                return [
                    ("X", timestamp, Double(value.0)),
                    ("Y", timestamp, Double(value.1)),
                    ("Z", timestamp, Double(value.2))
                ]
            case .temperature:
                return [
                    ("Temperature", timestamp, Double(self.apiCalliope?.temperature ?? 0))
                ]
            case .uart:
                guard self.apiCalliope?.uartValueNotification != nil else {
                    self.apiCalliope?.uartValueNotification = {
                        value in
                        self.value = value }
                    return [("",  0, 0.0)]
                }
                guard let value = self.value as? String else {
                    return [("",  0, 0.0)]
                }
                let stringList = value.split(separator: ":")
                return [(String(stringList[0]), timestamp, Double(stringList[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0)]
            default:
                return [("",  0, 0.0)]
            }
        }
    }
}
