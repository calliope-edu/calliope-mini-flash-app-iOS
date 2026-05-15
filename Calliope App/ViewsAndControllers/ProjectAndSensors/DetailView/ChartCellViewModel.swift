//
//  ChartViewModel.swift
//  Calliope App
//
//  Created by Calliope on 24.04.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import MapKit
import SwiftUI

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
            longitude: long
        )
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.location.latitude == rhs.location.latitude
            && lhs.location.longitude == rhs.location.longitude
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(location.latitude)
        hasher.combine(location.longitude)
    }
}

class ChartCellViewModel: ObservableObject, Identifiable {
    var chart: Chart
    @Published var sensorOptions: [DropDownOption<Sensor>] = []
    @Published var selectedSensor: DropDownOption<Sensor>?
    let dataController: DataController
    var baseTime: Double?
    @Published var isRecording: Bool = false
    @Published var axisOptions: [DropDownOption<Bool?>] = []
    @Published var selectedAxis: DropDownOption<Bool?>?
    @Published var data: [String: [DataPoint]] = [:]
    @Published var uniqueLocations: Set<IdentifiableLocation> = Set<
        IdentifiableLocation
    >()
    @Published var region: MKCoordinateRegion = getDefaultRegion()

    var flatChartData: [ChartDataPoint] {
        return data.flatMap {
            series,
            dataPoints in
            return dataPoints.map {
                ChartDataPoint(
                    x: $0.x,
                    y: $0.y,
                    series: series
                )
            }
        }
    }

    var displayedChartData: [ChartDataPoint] {
        return flatChartData.filter {
            selectedAxis == nil || selectedAxis!.name == "all"
                || selectedAxis!.name == $0.series
        }
    }
    
    var displayedYs: [Double] {
        return displayedChartData.map { $0.y }
    }

    var dataYs: [Double] {
        return flatChartData.map { $0.y }
    }
    
    var dislpayedMinimum: Double? {
        return displayedYs.min()
    }
    var absoluteMinimum: Double? {
        return dataYs.min()
    }
    
    var dislpayedMaximum: Double? {
        return displayedYs.max()
    }
    var absoluteMaximum: Double? {
        return dataYs.max()
    }
    
    var displayedAverage: Double? {
        if selectedAxis == nil || selectedAxis!.name == "all" { return nil } // only calculate if the displayed data has only one axis
        return calculateAverageMetric(values: displayedYs)
    }
    
    var displayedCurrent: Double? {
        if selectedAxis == nil || selectedAxis!.name == "all" { return nil } // only calculate if the displayed data has only one axis
        return displayedYs.last
    }
    
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!

    @Published var fileShareLink: URL?
    var openFileNameDialog: (@escaping (_ filename: String) -> Void) -> Void

    init(
        chart: Chart,
        openFileNameDialog:
            @escaping (@escaping (_ filename: String) -> Void) -> Void
    ) {
        self.chart = chart
        self.openFileNameDialog = openFileNameDialog
        dataController = DataController()
        loadDatabaseDataIntoChart(chart)
        updateAvailableSensors()
        updateAvailableAxis()
        calculateCenterRegion()
        addNotificationSubscriptions()
        self.selectedSensor = sensorOptions.first(where: { sensorOption in
            sensorOption.object.calliopeService.uuid
                == self.chart.sensorType?.uuid
        })
    }

    func calculateCenterRegion() {
        if uniqueLocations.isEmpty {
            region = ChartCellViewModel.getDefaultRegion()
            return
        }

        var center = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        if uniqueLocations.count > 0 {
            for place in uniqueLocations {
                center.latitude += place.location.latitude
                center.longitude += place.location.longitude
            }
            center.latitude /= Double(uniqueLocations.count)
            center.longitude /= Double(uniqueLocations.count)
        }

        var maxDistanceFromCenter = 0.002
        let centerCL = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude
        )
        for place in uniqueLocations {
            let distance = centerCL.distance(
                from: CLLocation(
                    latitude: place.location.latitude,
                    longitude: place.location.longitude
                )
            )
            if distance > maxDistanceFromCenter {
                maxDistanceFromCenter = distance
            }
        }

        region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: maxDistanceFromCenter,
                longitudeDelta: maxDistanceFromCenter
            )
        )
    }

    static private func getDefaultRegion() -> MKCoordinateRegion {
        // shows Berlin by default
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.4050),
            span: MKCoordinateSpan(
                latitudeDelta: 0.1,
                longitudeDelta: 0.1
            )
        )
    }

    let colors = [
        Color.red, Color.green, Color.blue, Color.orange, Color.purple,
    ]

    func getColorForAxis(axis: String) -> Color {
        let index = axisOptions.firstIndex { axisOption in
            axisOption.name == axis
        }
        return colors[(index ?? 0) % colors.count]
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
        axisOptions = []
        for (axis, _) in data {
            axisOptions.append(DropDownOption(name: axis, object: nil))
        }

        if axisOptions.count > 1 {
            let allOption = DropDownOption<Bool?>(name: "all", object: nil)
            axisOptions.append(allOption)
            selectedAxis = allOption
        } else if axisOptions.count == 1 {
            selectedAxis = axisOptions[0]
        }
    }

    private func calculateAverageMetric(values: [Double]) -> Double {
        var sum = 0.0
        values.forEach { sum += $0 }
        return sum / Double(values.count)
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            guard
                selectedSensor != nil
                    && !DataController.activeServices.contains(
                        selectedSensor!.object.calliopeService
                    )
            else {
                return
            }
            startRecording()
        }
    }

    func startRecording() {
        if baseTime == nil {
            baseTime = (Date().timeIntervalSinceReferenceDate * 100).rounded(
                toPlaces: 0
            )
        }
        dataController.sensorStartRecordingFor(chart: chart) {
            (axis, time, value, coordinates) in
            if self.isRecording {
                if self.data[axis] == nil {
                    self.data[axis] = []
                }
                self.data[axis]?.append(
                    DataPoint(
                        x: time - (self.baseTime ?? 0),
                        y: value,
                        location: coordinates
                    )
                )
                self.updateAvailableAxis()
                if coordinates != nil {
                    self.uniqueLocations.insert(
                        IdentifiableLocation(
                            lat: coordinates!.latitude,
                            long: coordinates!.longitude
                        )
                    )
                    self.calculateCenterRegion()
                }
            }
        }
        Chart.setSensorType(chart: chart)
        isRecording = true
    }

    func stopRecording() {
        dataController.sensorStopRecordingFor(chart: chart)
        isRecording = false
    }

    //TODO: Add button to execute this
    func exportAsCSV() {
        openFileNameDialog({ filename in
            let string = CSVHandler.convertToCSVString(
                chartId: self.chart.id!,
                sensorType: self.chart.sensorType
            )
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
                let decodedValue = DataParser.decode(
                    data: value.value,
                    service: chart.sensorType ?? .empty
                )
                for key in decodedValue.keys {
                    if key == "" {
                        break
                    }
                    guard let datapoint = decodedValue[key],
                        let baseTime = baseTime
                    else {
                        return
                    }
                    let newDataPoint: DataPoint = DataPoint(
                        x: Double(value.time) - baseTime,
                        y: datapoint,
                        location: nil
                    )
                    if data[key] != nil {
                        data[key]!.append(newDataPoint)
                    } else {
                        data.updateValue([newDataPoint], forKey: key)
                    }
                }
                if value.lat != nil && value.long != nil {
                    uniqueLocations.insert(
                        IdentifiableLocation(lat: value.lat!, long: value.long!)
                    )
                }
            }
        }
        updateAvailableSensors()
        updateAvailableSensors()
    }

    fileprivate func addNotificationSubscriptions() {
        calliopeConnectedSubcription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDevice.usageReadyNotificationName,
            object: nil,
            queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    LogNotify.log("Received usage ready Notification")
                    self?.updateAvailableSensors()
                }
            }
        )

        calliopeDisconnectedSubscription = NotificationCenter.default
            .addObserver(
                forName: DiscoveredBLEDevice.disconnectedNotificationName,
                object: nil,
                queue: nil,
                using: { [weak self] (_) in
                    DispatchQueue.main.async {
                        self?.stopRecording()
                        self?.selectedSensor = nil
                    }
                }
            )
    }

    deinit {
        NotificationCenter.default.removeObserver(calliopeConnectedSubcription!)
        NotificationCenter.default.removeObserver(
            calliopeDisconnectedSubscription!
        )
    }

}
