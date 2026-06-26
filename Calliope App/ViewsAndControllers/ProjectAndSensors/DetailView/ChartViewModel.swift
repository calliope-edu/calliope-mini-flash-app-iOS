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
    let location: IdentifiableLocation?
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

// TODO: ChartCellViewControlStructure

class ChartViewModel: ObservableObject, Identifiable {
    var chart: Chart
    let onNewLocation: (_ location: IdentifiableLocation) -> Void
    let markLocation: (_ location: IdentifiableLocation, _ chart: Chart) -> Void
    let getMarkerColorForChart: (_ chart: Chart) -> Color
    let dataController: DataController
    @Published var data: [String: [DataPoint]] = [:]
    @Published var sensorOptions: [DropDownOption<Sensor>] = []
    @Published var selectedSensor: DropDownOption<Sensor>?
    @Published var isRecording: Bool = false
    @Published var axisOptions: [DropDownOption<Bool?>] = []
    @Published var selectedAxis: DropDownOption<Bool?>?
    var baseTime: Double?
    @Published var sliderPosition: Double = 0.0 {
        willSet {
            updateMarkedLocation()
        }
    }

    func updateMarkedLocation() {
        let dataPoint = findPointClosestToSlider()
        if dataPoint != nil && dataPoint!.location != nil {
            markLocation(dataPoint!.location!, chart)
        }
    }

    @Published var currentScale: CGFloat = 1.0
    @Published var currentOffset: CGSize = .zero
    @Published var displayedRange: ClosedRange<Double>?

    let minimumGraphScale = 0.001
    let maximumGraphScale = 1.0

    var totalRangeWidth: Double {
        return (maximumX ?? 1) - (minimumX ?? 0)
    }

    func updateDisplayedRange(graphWidth: Double, gestureOffset: CGSize, gestureScale: Double) {
        let offset = currentOffset.width + gestureOffset.width
        let displayedMinimumX = offset - totalRangeWidth * currentScale * gestureScale / 2
        let displayedMaximumX = offset + totalRangeWidth * currentScale * gestureScale / 2
        displayedRange = displayedMinimumX...displayedMaximumX
    }

    func ensureOffsetInBounds(graphWidth: Double) {
        if displayedRange!.lowerBound < (minimumX ?? 0) {
            let shift = (minimumX ?? 0) - displayedRange!.lowerBound
            currentOffset.width = currentOffset.width + shift
        } else if displayedRange!.upperBound > (maximumX ?? 1) {
            let shift = displayedRange!.upperBound - (maximumX ?? 1)
            currentOffset.width = currentOffset.width - shift
        }
    }

    var flatChartData: [ChartDataPoint] {
        return data.flatMap {
            series,
            dataPoints in
            return dataPoints.map {
                ChartDataPoint(
                    x: $0.x,
                    y: $0.y,
                    series: series,
                    location: $0.location
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
        if selectedAxis == nil || selectedAxis!.name == "all" { return nil }  // only calculate if the displayed data has only one axis
        return calculateAverageMetric(values: displayedYs)
    }

    var displayedCurrent: Double? {
        if selectedAxis == nil || selectedAxis!.name == "all" { return nil }  // only calculate if the displayed data has only one axis

        return findPointClosestToSlider()?.y
    }

    func findPointClosestToSlider() -> ChartDataPoint? {
        if displayedChartData.isEmpty {
            return nil
        }

        var sortedDataPoints = displayedChartData
        sortedDataPoints.sort { $0.x < $1.x }

        for i in 0..<sortedDataPoints.count {
            if sortedDataPoints[i].x > sliderAxisValue {
                return sortedDataPoints[max(i - 1, 0)]
            }
        }

        return sortedDataPoints[sortedDataPoints.count - 1]
    }

    var sliderAxisValue: Double {
        sliderPosition * ((displayedRange?.upperBound ?? 1) - (displayedRange?.lowerBound ?? 0)) + (displayedRange?.lowerBound ?? 0)
    }

    func axisValueToSlider(xValue: Double) -> Double {
        (xValue - (displayedRange?.lowerBound ?? 0)) / ((displayedRange?.upperBound ?? 1) - (displayedRange?.lowerBound ?? 0))
    }

    var minimumX: Double? {
        displayedChartData.map { $0.x }.min()
    }

    var maximumX: Double? {
        displayedChartData.map { $0.x }.max()
    }

    var minimumXDistance: Double? {
        let sortedXs = displayedChartData.map { $0.x }.sorted()
        var minimumDistance = Double.infinity
        for i in 0...(sortedXs.count - 2) {
            let distance = sortedXs[i + 1] - sortedXs[i]
            if distance < minimumDistance {
                minimumDistance = distance
            }
        }
        return minimumDistance
    }

    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!

    var openFileNameDialog: (@escaping (_ filename: String) -> Void) -> Void

    init(
        chart: Chart,
        openFileNameDialog:
            @escaping (@escaping (_ filename: String) -> Void) -> Void,
        onNewLocation: @escaping (_ location: IdentifiableLocation) -> Void,
        markLocation: @escaping (_ location: IdentifiableLocation, _ chart: Chart) -> Void,
        getMarkerColorForChart: @escaping (_ chart: Chart) -> Color
    ) {
        self.chart = chart
        self.openFileNameDialog = openFileNameDialog
        self.onNewLocation = onNewLocation
        self.markLocation = markLocation
        self.getMarkerColorForChart = getMarkerColorForChart

        dataController = DataController()
        loadDatabaseDataIntoChart(chart)
        updateAvailableAxis()
        addNotificationSubscriptions()
        self.selectedSensor = sensorOptions.first(where: { sensorOption in
            sensorOption.object.calliopeService.uuid
                == self.chart.sensorType?.uuid
        })
    }

    func markValueForLocation(location: IdentifiableLocation) {
        var flatData = data.flatMap { $0.value.map { $0 } }
        flatData.sort { $0.x < $1.x }
        let xValue = flatData.first(where: { $0.location == location })?.x
        if xValue != nil {
            sliderPosition = axisValueToSlider(xValue: xValue!)
        }
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

    fileprivate func saveDataPoint(_ axis: String, _ time: Double, _ value: Double, _ coordinates: CLLocationCoordinate2D?) {
        if self.data[axis] == nil {
            self.data[axis] = []
        }
        var location: IdentifiableLocation? = nil
        if coordinates != nil {
            location = IdentifiableLocation(
                lat: coordinates!.latitude,
                long: coordinates!.longitude
            )
            onNewLocation(location!)
        }
        self.data[axis]?.append(
            DataPoint(
                x: time - (self.baseTime ?? 0),
                y: value,
                location: location
            )
        )
        self.updateAvailableAxis()
        displayedRange = (minimumX ?? 0)...(maximumX ?? 1) // show the user the entire plot
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
                self.saveDataPoint(axis, time, value, coordinates)
            }
        }
        Chart.setSensorType(chart: chart)
        isRecording = true
    }

    func stopRecording() {
        dataController.sensorStopRecordingFor(chart: chart)
        isRecording = false
    }

    func exportAsCSV() {
        openFileNameDialog({ filename in
            let string = CSVHandler.convertToCSVString(
                chartId: self.chart.id!,
                sensorType: self.chart.sensorType
            )
            CSVHandler.exportToCSVFile(contents: string, fileName: filename)
        })
    }

    fileprivate func loadValue(_ value: Value, _ chart: Chart) {
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
            var location: IdentifiableLocation? = nil
            if value.lat != nil && value.long != nil {
                location = IdentifiableLocation(lat: value.lat!, long: value.long!)
            }
            let newDataPoint: DataPoint = DataPoint(
                x: Double(value.time) - baseTime,
                y: datapoint,
                location: location
            )
            if data[key] != nil {
                data[key]!.append(newDataPoint)
            } else {
                data.updateValue([newDataPoint], forKey: key)
            }
        }
    }

    fileprivate func loadDatabaseDataIntoChart(_ chart: Chart) {
        let rawValues = Value.fetchValuesBy(chartId: chart.id)
        if !rawValues.isEmpty {
            if baseTime == nil {
                baseTime = rawValues.first?.time
            }
            for value in rawValues {
                loadValue(value, chart)
            }
        }
        if data.isEmpty {  // allow to choose a new sensor, if no data has been recorded yet
            updateAvailableSensors()
        } else {
            if chart.sensorType == nil {
                setUnkownSensor()
            }
            let sensor = SensorUtility.serviceSensorMap[chart.sensorType!]
            if sensor == nil {
                setUnkownSensor()
            }
            let dropdownOption = DropDownOption<Sensor>(
                name: sensor!.name,
                object: sensor!
            )
            sensorOptions = [dropdownOption]
            selectedSensor = dropdownOption
        }
    }

    func setUnkownSensor() {
        let sensor = Sensor(
            calliopeService: CalliopeService.empty,
            name: "Unkown Sensor",
            numOfAxis: 0
        )
        let dropDownOption = DropDownOption<Sensor>(
            name: sensor.name,
            object: sensor
        )
        sensorOptions = [dropDownOption]
        selectedSensor = dropDownOption
    }
    
    func getMarkerColor() -> Color {
        return self.getMarkerColorForChart(chart)
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
