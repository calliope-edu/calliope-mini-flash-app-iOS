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

struct IdentifiableLocation: Identifiable, Hashable {
    let id: UUID
    let location: CLLocationCoordinate2D
    init(id: UUID = UUID(), lat: Double, long: Double) {
        self.id = id
        self.location = CLLocationCoordinate2D(
            latitude: lat,
            longitude: long)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.location.latitude == rhs.location.latitude &&
        lhs.location.longitude == rhs.location.longitude
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(location.latitude)
        hasher.combine(location.longitude)
    }
}

class ChartViewModel: ObservableObject, Identifiable {
    var chart: Chart
    @Published var sensorOptions: [DropDownOption<Sensor>] = []
    @Published var selectedSensor: DropDownOption<Sensor>?
    let dataController: DataController
    var baseTime: Double?
    @Published var isRecording: Bool = false
    @Published var axisOptions: [DropDownOption<Bool?>] = []
    @Published var selectedAxis: DropDownOption<Bool?>?
    @Published var data: [String: [DataPoint]] = [:]
    @Published var uniqueLocations: Set<IdentifiableLocation> = Set<IdentifiableLocation>()
    
    @Published var minimumMetric: Double?
    @Published var averageMetric: Double?
    @Published var maximumMetric: Double?
    @Published var currentMetric: Double?
    
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    
    @Published var fileShareLink: URL?
    var openFileNameDialog: (@escaping (_ filename: String) -> Void) -> ()
    
    init(chart: Chart, openFileNameDialog: @escaping (@escaping (_ filename: String) -> Void) -> ()) {
        self.chart = chart
        self.openFileNameDialog = openFileNameDialog
        dataController = DataController()
        loadDatabaseDataIntoChart(chart)
        updateAvailableSensors()
        updateAvailableAxis()
        addNotificationSubscriptions()
        self.selectedSensor = sensorOptions.first(where: {sensorOption in sensorOption.object.calliopeService.uuid == self.chart.sensorType?.uuid})
        updateMetrics()
    }
    
    func updateAvailableSensors() {
        sensorOptions = dataController.getAvailableSensors().map { sensor in
            DropDownOption(name: sensor.name, object: sensor)
        }
    }
    
    func selectSensor(selection: DropDownOption<Sensor>) {
        selectedSensor = selection
        chart.sensorType = selection.object.calliopeService
    }
    
    func selectAxis(selection: DropDownOption<Bool?>) {
        selectedAxis = selection
    }
    
    func updateAvailableAxis() {
        for (axis, _) in data {
            axisOptions.append(DropDownOption(name: axis, object: nil))
        }
        
        if axisOptions.count > 1 {
            let allOption = DropDownOption<Bool?>(name: "all", object: nil)
            axisOptions.append(allOption)
            selectedAxis = allOption
        }
        else if axisOptions.count == 1 {
            selectedAxis = axisOptions[0]
        }
    }
    
    func updateMetrics() {
        let values = data.flatMap{ axis, dataPoints in dataPoints.map{ $0.y}}
        if data.count > 1 {
            minimumMetric = values.min()
            maximumMetric = values.max()
            averageMetric = nil
            currentMetric = nil
        }
        else if data.count == 1 {
            minimumMetric = values.min()
            maximumMetric = values.max()
            averageMetric = calculateAverageMetric(values: values)
            currentMetric = values.last
            
        }
        else {
            minimumMetric = nil
            maximumMetric = nil
            averageMetric = nil
            currentMetric = nil
        }
    }
    
    func calculateAverageMetric(values: [Double]) -> Double {
        var sum = 0.0
        values.forEach{ sum += $0}
        return sum / Double(values.count)
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
                self.data[axis]?.append(DataPoint(x: time - (self.baseTime ?? 0), y: value, location: coordinates))
                self.updateMetrics()
                self.updateAvailableAxis()
                if coordinates != nil {
                    self.uniqueLocations.insert(IdentifiableLocation(lat: coordinates!.latitude, long: coordinates!.longitude))
                }
            }
        }
        isRecording = true
    }
    
    func stopRecording() {
        dataController.sensorStopRecordingFor(chart: chart)
        isRecording = false
    }
    
    //TODO: Add button to execute this
    func exportAsCSV() {
        openFileNameDialog({ filename in
            let string = CSVHandler.convertToCSVString(chartId: self.chart.id!, sensorType: self.chart.sensorType)
            CSVHandler.exportToCSVFile(contents: string, fileName: filename)
        })
    }
    
    fileprivate func loadDatabaseDataIntoChart(_ chart: Chart) {
        let rawValues = Value.fetchValuesBy(chartId: chart.id)
        if !rawValues.isEmpty {
            if baseTime == nil {
                baseTime = rawValues.first?.time
            }
            for value in rawValues {
                let decodedValue = DataParser.decode(data: value.value, service: chart.sensorType ?? .empty)
                for key in decodedValue.keys {
                    if key == "" {
                        break
                    }
                    guard let datapoint = decodedValue[key], let baseTime = baseTime else {
                        return
                    }
                    let newDataPoint: DataPoint = DataPoint(x: Double(value.time) - baseTime, y: datapoint, location: nil)
                    if(data[key] != nil) {
                        data[key]!.append(newDataPoint)
                    }
                    else {
                        data.updateValue([newDataPoint], forKey: key)
                    }
                }
                if(value.lat != nil && value.long != nil) {
                    uniqueLocations.insert(IdentifiableLocation(lat: value.lat!, long: value.long!))
                }
            }
        }
        updateAvailableSensors()
        updateAvailableSensors()
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
