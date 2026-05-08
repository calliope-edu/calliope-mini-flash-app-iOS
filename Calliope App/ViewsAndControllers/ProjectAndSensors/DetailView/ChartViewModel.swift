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

class ChartViewModel: ObservableObject {
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

    init(chart: Chart) {
        self.chart = chart
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
//                self.getDataEntries(data: [axis: value], timestep: time, service: chart.sensorType ?? .empty)
                if coordinates != nil {
                    self.uniqueLocations.insert(IdentifiableLocation(lat: coordinates!.latitude, long: coordinates!.longitude))
                }
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
   
    //TODO: Add button to execute this
    private func exportAsCSV() {
//        guard let chart = chart else { return }
//        let values = Value.fetchValuesBy(chartId: chart.id)
//        guard !values.isEmpty else { return }
//
//        var allKeys: [String] = []
//        for value in values {
//            let decoded = DataParser.decode(data: value.value, service: chart.sensorType ?? .empty)
//            for key in decoded.keys where !allKeys.contains(key) { allKeys.append(key) }
//        }
//        allKeys.sort()
//
//        let timeFmt = DateFormatter()
//        timeFmt.dateFormat = "HH:mm:ss"
//        let dateFmt = DateFormatter()
//        dateFmt.dateFormat = "dd/MM/yy"
//
//        var lines = ["date,time," + allKeys.joined(separator: ",")]
//        for value in values {
//            let date = Date(timeIntervalSinceReferenceDate: value.time / 100.0)
//            let decoded = DataParser.decode(data: value.value, service: chart.sensorType ?? .empty)
//            let cols = allKeys.map { decoded[$0].map { String($0) } ?? "" }
//            lines.append("\(dateFmt.string(from: date)),\(timeFmt.string(from: date)),\(cols.joined(separator: ","))")
//        }
//
//        let tmpURL = FileManager.default.temporaryDirectory
//            .appendingPathComponent("sensor_\(chart.id ?? 0).csv")
//        do {
//            try lines.joined(separator: "\n").write(to: tmpURL, atomically: true, encoding: .utf8)
//        } catch {
//            LogNotify.log("Failed to write CSV: \(error)")
//            return
//        }
//
//        let activityVC = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
//        if let popover = activityVC.popoverPresentationController {
//            popover.sourceView = self
//            popover.sourceRect = self.bounds
//        }
//        nearestViewController()?.present(activityVC, animated: true)
    }
    
    fileprivate func loadDatabaseDataIntoChart(_ chart: Chart) {
        LogNotify.log("Starting to load existing Data into Chart")
        let rawValues = Value.fetchValuesBy(chartId: chart.id)
        LogNotify.log("Got the raw values")
        if !rawValues.isEmpty {
            if baseTime == nil {
                baseTime = rawValues.first?.time
                if let baseTime = baseTime {
//                    lineChartView.xAxis.valueFormatter = TimeAxisValueFormatter(baseTime: baseTime)
                }
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
//                getDataEntries(data: decodedValue, timestep: value.time, service: chart.sensorType ?? .empty)
                if(value.lat != nil && value.long != nil) {
                    uniqueLocations.insert(IdentifiableLocation(lat: value.lat!, long: value.long!))
                }
//                handleLocationData(CLLocationCoordinate2D(latitude: value.lat, longitude: value.long), value.time)
            }
//            addDataEntries(dataEntries: axisToData)
            
//            sensorTypeButton.isEnabled = false
//            recordingButton.isEnabled = false
        } else {
//            sensorTypeButton.isEnabled = true
//            recordingButton.isEnabled = (chart.sensorType != nil)
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
