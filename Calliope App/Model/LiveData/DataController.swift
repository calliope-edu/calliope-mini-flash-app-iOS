//
//  DataController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import CoreLocation
import Foundation

class DataController: NSObject, CLLocationManagerDelegate {

    var availableSensors: [Sensor] = []
    static var activeServices: [CalliopeService] = []
    var apiCalliope: CalliopeAPI?
    var isRecording = false
    var timer: Timer?

    var uartValue: [Any] = []

//    var getLastLocation: (() -> CLLocationCoordinate2D?)?
    let locationManager = CLLocationManager()

    /// The Bluetooth-connected Calliope mini, if it can deliver sensor values.
    /// Deliberately not `usageReadyCalliope`: that follows the USB/Bluetooth
    /// switch and reports the USB device (or nil) while the switch is on USB,
    /// even though sensor values only ever come over Bluetooth.
    private static var sensorCapableCalliope: CalliopeAPI? {
        MatrixConnectionViewModel.instance.connector
            .connectedCalliope?.usageReadyCalliope as? CalliopeAPI
    }

    override init() {
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
    
    var baseTime: Double?

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
            askForLocationAuthorization()
            self.baseTime = (Date().timeIntervalSinceReferenceDate * 100).rounded(toPlaces: 0)
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let newValue = self.fetchValue(service: chart.sensorType ?? .empty)
                for (axis, time, value) in newValue {
                    let parsedValue = DataParser.encode(data: [axis: value], service: chart.sensorType ?? .empty)
                    let coordinates = self.getLastLocation()
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
    
    func randomlyAlterLocation(_ location: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        if location == nil {
            return nil
        }
        
        let latitudeNoise = Double(Int.random(in: 0...100)) / 10000
        let longitudeNoise = Double(Int.random(in: 0...100)) / 10000
        return CLLocationCoordinate2D(latitude: location!.latitude + latitudeNoise, longitude: location!.longitude + longitudeNoise)
    }
    
    func linearlyAlterLocation(location: CLLocationCoordinate2D?, time: Double) -> CLLocationCoordinate2D? {
        if location == nil {
            return nil
        }
        
        let longitudeShift = (time - self.baseTime!) / 10000
        return CLLocationCoordinate2D(latitude: location!.latitude, longitude: location!.longitude + longitudeShift)
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
    
    // #MARK: LOCATION RELEVANT FUNCTIONS
    private let COORDINATE_PRECISION = 4

    func setupLocationManager() {
        LogNotify.log("Init Location Updates; Auth status \(locationManager.authorizationStatus)")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        LogNotify.log("Maps will be \(self.isAuthorizedForLocation() ? "shown" : "hidden"), as Auth Status \(locationManager.authorizationStatus)")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        LogNotify.log("Got new Location Data - Location Manager holds Long: \(self.locationManager.location?.coordinate.longitude ?? 0.0) Lat: \(self.locationManager.location?.coordinate.latitude ?? 0.0)")
    }

    private func getLastLocation() -> CLLocationCoordinate2D? {
        return self.locationManager.location?.coordinate.rounded(toPlaces: COORDINATE_PRECISION) ?? nil
    }
    
    private func isAuthorizedForLocation() -> Bool {
        [CLAuthorizationStatus.authorizedAlways, CLAuthorizationStatus.authorizedWhenInUse].contains(self.locationManager.authorizationStatus)
    }
    
    private func askForLocationAuthorization() {
        if !isAuthorizedForLocation() && self.locationManager.authorizationStatus == CLAuthorizationStatus.notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
}
