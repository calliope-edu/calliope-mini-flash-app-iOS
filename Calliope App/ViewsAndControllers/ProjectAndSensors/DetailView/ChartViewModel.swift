//
//  ChartViewModel.swift
//  Calliope App
//
//  Created by Calliope on 24.04.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import MapKit

struct DataPoint {
    let x: Double
    let y: Double
    let location: CLLocationCoordinate2D?
}

class ChartViewModel: ObservableObject {
    let chart: Chart
    @Published var sensorOptions: [DropDownOption<Sensor>] = []
    @Published var selectedSensor: DropDownOption<Sensor>?
    let dataController: DataController
    var baseTime: Double?
    @Published var isRecording: Bool = false
    @Published var axisOptions: [DropDownOption<Void>] = []
    @Published var selectedAxis: DropDownOption<Void>?
    @Published var data: [String: [DataPoint]] = [:]
    
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!

    init(chart: Chart) {
        self.chart = chart
        dataController = DataController()
        loadDatabaseDataIntoChart(chart)
        updateAvailableSensors()
        addNotificationSubscriptions()
    }
    
    func updateAvailableSensors() {
        sensorOptions = dataController.getAvailableSensors().map { sensor in
            DropDownOption(name: sensor.name, object: sensor)
        }
    }
    
    func selectSensor(selection: DropDownOption<Sensor>) {
        selectedSensor = selection
    }
    
    func selectAxis(selection: DropDownOption<Void>) {
        selectedAxis = selection
    }
    
    func updateAvailableAxis() {
        
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        }
        else {
            guard selectedSensor != nil && !DataController.activeServices.contains(selectedSensor!.object.calliopeService) else {
                return
            }
            startRecording()
        }
    }
    
    func startRecording() {
        if baseTime == nil {
            baseTime = (Date().timeIntervalSinceReferenceDate * 100).rounded(toPlaces: 0)
        }
        dataController.sensorStartRecordingFor(chart: chart) { (axis, time, value, coordinates) in
            if self.isRecording {
                if self.data[axis] == nil {
                    self.data[axis] = []
                }
                self.data[axis]?.append(DataPoint(x: time, y: value, location: coordinates))
//                self.getDataEntries(data: [axis: value], timestep: time, service: chart.sensorType ?? .empty)
//                self.handleLocationData(coordinates, time)
//                self.addDataEntries(dataEntries: self.axisToData)
            }
        }
        
//        dataController.getLastLocation = getLastLocation
        isRecording = true
    }
    
    func stopRecording() {
        dataController.sensorStopRecordingFor(chart: chart)
        isRecording = false
    }
    
    fileprivate func loadDatabaseDataIntoChart(_ chart: Chart) {
        LogNotify.log("Starting to load existing Data into Chart")
        let rawValues = Value.fetchValuesBy(chartId: chart.id)
        LogNotify.log("Got the raw values")
        if !rawValues.isEmpty {
            /*if baseTime == nil {
                baseTime = rawValues.first?.time
                if let baseTime = baseTime {
                    lineChartView.xAxis.valueFormatter = TimeAxisValueFormatter(baseTime: baseTime)
                }
            }*/
            for value in rawValues {
                let decodedValue = DataParser.decode(data: value.value, service: chart.sensorType ?? .empty)
                for key in decodedValue.keys {
                    print(key)
                    if key == "" {
                        break
                    }
                    guard let datapoint = decodedValue[key], let baseTime = baseTime else {
                        return
                    }
                    data[key]?.append(DataPoint(x: Double(value.time) - baseTime, y: datapoint, location: nil))
                    print(Double(value.time) - baseTime, datapoint)
                }
//                getDataEntries(data: decodedValue, timestep: value.time, service: chart.sensorType ?? .empty)
//                handleLocationData(CLLocationCoordinate2D(latitude: value.lat, longitude: value.long), value.time)
            }
//            addDataEntries(dataEntries: axisToData)
            
//            sensorTypeButton.isEnabled = false
//            recordingButton.isEnabled = false
        } else {
//            sensorTypeButton.isEnabled = true
//            recordingButton.isEnabled = (chart.sensorType != nil)
        }
        print(data)
        LogNotify.log("Done")
    }
    
    
    fileprivate func addNotificationSubscriptions() {
        calliopeConnectedSubcription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDevice.usageReadyNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    LogNotify.log("Received usage ready Notification")
                    self?.updateAvailableSensors()
                }
            })

        calliopeDisconnectedSubscription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDevice.disconnectedNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.stopRecording()
                    self?.selectedSensor = nil
                }
            })
    }
    
    deinit {
        NotificationCenter.default.removeObserver(calliopeConnectedSubcription!)
        NotificationCenter.default.removeObserver(calliopeDisconnectedSubscription!)
    }

}
