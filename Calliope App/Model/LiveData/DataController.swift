//
//  DataController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import CoreLocation
import Foundation

class DataController {

    var availableSensors: [Sensor] = []
    static var activeServices: [CalliopeService] = []
    var apiCalliope: CalliopeAPI?
    var isRecording = false
    var timer: Timer?

    var uartValue: [Any] = []

    var getLastLocation: (() -> CLLocationCoordinate2D?)?

    /// The Bluetooth-connected Calliope mini, if it can deliver sensor values.
    /// Deliberately not `usageReadyCalliope`: that follows the USB/Bluetooth
    /// switch and reports the USB device (or nil) while the switch is on USB,
    /// even though sensor values only ever come over Bluetooth.
    private static var sensorCapableCalliope: CalliopeAPI? {
        MatrixConnectionViewController.instance.connector
            .connectedCalliope?.usageReadyCalliope as? CalliopeAPI
    }

    init() {
        guard let connectedCalliope = DataController.sensorCapableCalliope else {
            return
        }
        self.apiCalliope = connectedCalliope
        self.availableSensors =
            apiCalliope?.discoveredOptionalServices.compactMap { key in
                return SensorUtility.serviceSensorMap[key]
            } ?? []
    }

    func getAvailableSensors() -> [Sensor] {
        apiCalliope = DataController.sensorCapableCalliope
        return apiCalliope?.discoveredOptionalServices.compactMap { key in
            return SensorUtility.serviceSensorMap[key]
        } ?? []
    }

    func sensorStartRecordingFor(chart: Chart, response: @escaping ((String, Double, Double, CLLocationCoordinate2D?)) -> Void) {
        if DataController.activeServices.contains(chart.sensorType ?? .empty) {
            isRecording = false
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
                let newValue = self.fetchValue(service: chart.sensorType ?? .empty)
                for (axis, time, value) in newValue {
                    let parsedValue = DataParser.encode(data: [axis: value], service: chart.sensorType ?? .empty)
                    let coordinates = self.getLastLocation?()
                    Value.insertValue(value: parsedValue, coordinates: coordinates, chartsId: chart.id!)
                    response((axis, time, value, coordinates))
                }
            }
            self.isRecording = true
            DataController.activeServices.append(chart.sensorType ?? .empty)
        } else {
            // Nothing was started: the Calliope mini does not expose this
            // service. A micro:bit/Calliope only advertises the BLE services its
            // running program actually uses, so a program without the Bluetooth
            // UART service means no UART sensor data — worth seeing in the log,
            // because the UI otherwise just stays empty.
            LogNotify.log("Sensor \(String(describing: chart.sensorType)) is not among the available sensors \(self.getAvailableSensors().map { $0.calliopeService }) - not recording")
        }
    }

    func sensorStopRecordingFor(chart: Chart) {
        timer?.invalidate()
        if chart.sensorType == .uart {
            apiCalliope?.uartValueNotification = nil
        }
        isRecording = false
        _ = DataController.activeServices.remove(object: chart.sensorType ?? .empty)
    }

    func fetchValue(service: CalliopeService) -> [(String, Double, Double)] {
        asyncAndWait(on: DispatchQueue.global(qos: .userInitiated)) {
            let timestamp = (Date().timeIntervalSinceReferenceDate * 100).rounded(toPlaces: 0)
            switch service {
            case .accelerometer:
                let value = self.apiCalliope?.accelerometerValue ?? (0, 0, 0)
                return [
                    ("X", timestamp, Double(value.0)),
                    ("Y", timestamp, Double(value.1)),
                    ("Z", timestamp, Double(value.2)),
                ]
            case .magnetometer:
                let value = self.apiCalliope?.magnetometerValue ?? (0, 0, 0)
                return [
                    ("X", timestamp, Double(value.0)),
                    ("Y", timestamp, Double(value.1)),
                    ("Z", timestamp, Double(value.2)),
                ]
            case .temperature:
                return [
                    (NSLocalizedString("Temperature", comment: ""), timestamp, Double(self.apiCalliope?.temperature ?? 0))
                ]
            case .uart:
                guard self.apiCalliope?.uartValueNotification != nil else {
                    self.apiCalliope?.uartValueNotification = {
                        value in
                        self.uartValue.append(value)
                    }
                    return [("", 0, 0.0)]
                }
                guard let uartValue = self.uartValue as? [String] else {
                    return [("", 0, 0.0)]
                }
                var returnValues: [(String, Double, Double)] = []
                for element in uartValue {
                    // A line has to look like "name:value". Anything else — an
                    // empty packet, a bare number, a line split across two BLE
                    // packets (UART carries 20 bytes at a time) — used to crash
                    // here on `stringList[1]`.
                    let stringList = element.split(separator: ":")
                    guard stringList.count >= 2 else {
                        LogNotify.log("UART sensor: ignoring line without \"name:value\" format: \(element)")
                        continue
                    }
                    let axis = String(stringList[0])
                    let rawValue = stringList[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let numericValue = Double(rawValue) else {
                        LogNotify.log("UART sensor: value for \(axis) is not a number: \(rawValue)")
                        continue
                    }
                    returnValues.append((axis, timestamp, numericValue))
                }
                self.uartValue.removeAll()
                return returnValues
            default:
                return [("", 0, 0.0)]
            }
        }
    }
}
