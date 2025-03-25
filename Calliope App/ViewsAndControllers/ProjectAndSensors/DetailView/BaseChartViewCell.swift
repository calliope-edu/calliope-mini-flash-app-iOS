//
//  ChartDataHandler.swift
//  Calliope App
//
//  Created by itestra on 02.07.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import DGCharts
import Foundation
import UIKit

protocol ChartCellDelegate {
    func deleteChart(of cell: ChartViewCell, chart: Chart?)
}

class BaseChartViewCell: UITableViewCell, ChartViewDelegate {

    var chart: Chart?
    var sensor: Sensor?
    var baseTime: Double?
    var isRecordingData: Bool = false
    var hasDefaultValues: Bool = false
    var selectedAxis: Int = -1

    public var delegate: ChartCellDelegate!
    public var dataController: DataController

    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var sensorTypeMenu: UIMenu!
    @IBOutlet weak var sensorTypeButton: ContextMenuButton!
    @IBOutlet weak var sensorAxisMenu: UIMenu!
    @IBOutlet weak var sensorAxisButton: ContextMenuButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var recordingButton: UIButton!
    @IBOutlet weak var maxValueLabel: UILabel!
    @IBOutlet weak var minValueLabel: UILabel!
    @IBOutlet weak var avgValueLabel: UILabel!
    @IBOutlet weak var currentValueLabel: UILabel!

    let colors = [NSUIColor.calliopeGreen, NSUIColor.calliopePurple, NSUIColor.calliopeYellow, NSUIColor.calliopeRed, NSUIColor.calliopeGray]


    var axisToDataSet: [String: LineChartDataSet] = [:]
    var axisToData: [String: [ChartDataEntry]] = [:]

    required init?(coder: NSCoder) {
        dataController = DataController()
        super.init(coder: coder)
    }

    @IBAction func startRecording(_ sender: Any) {
        if isRecordingData {
            stopDataRecording()
            return
        }
        guard let sensor = sensor else {
            return
        }
        if DataController.activeServices.contains(sensor.calliopeService) {
            return
        }
        UIView.animate(withDuration: 0.5) {
            self.sensorTypeButton.isEnabled = false
            self.deleteButton.isEnabled = false
            self.recordingButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
        startDataRecording()
    }

    func startDataRecording() {
        if hasDefaultValues {
            guard let dataSets = lineChartView.data?.dataSets else {
                return
            }
            for dataSet in dataSets {
                dataSet.clear()
            }
            hasDefaultValues = false
        }
        guard let chart = chart else {
            fatalError("chart has not been initialized before using the ChartViewCell")
        }
        if baseTime == nil {
            baseTime = (Date().timeIntervalSinceReferenceDate * 100).rounded(toPlaces: 0)
        }
        dataController.sensorStartRecordingFor(chart: chart) { value in
            if self.isRecordingData {
                guard let chart = self.chart else {
                    fatalError()
                }
                self.getDataEntries(data: [value.0: value.2], timestep: value.1, service: chart.sensorType ?? .empty)
                self.addDataEntries(dataEntries: self.axisToData)
            }
        }
        isRecordingData = true
    }

    func stopDataRecording() {
        guard let chart = chart else {
            fatalError("chart has not been initialized before using the ChartViewCell")
        }
        dataController.sensorStopRecordingFor(chart: chart)
        isRecordingData = false

        UIView.animate(withDuration: 0.5) {
            self.deleteButton.isEnabled = true
            self.recordingButton.isEnabled = false
            self.recordingButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }

    func getDataEntries(data: [String: Double], timestep: Double, service: CalliopeService) {
        for key in data.keys {
            if key == "" {
                break
            }
            var dataSet: [ChartDataEntry] = axisToData[key] ?? []
            guard let datapoint = data[key], let baseTime = baseTime else {
                return
            }
            dataSet.append(ChartDataEntry(x: Double(timestep) - baseTime, y: datapoint))
            axisToData[key] = dataSet
        }
    }

    func addDataEntries(dataEntries: [String: [ChartDataEntry]]) {
        for key in dataEntries.keys {
            if axisToDataSet[key] == nil {
                let newLineChartDataset = LineChartDataSet(label: key).layoutDataSet(color: colors[axisToDataSet.keys.count])
                axisToDataSet[key] = newLineChartDataset
                setupSensorMenu()
            }
            guard let entries = dataEntries[key], let axisDataSet = axisToDataSet[key] else {
                return
            }
            for entry in entries {
                axisDataSet.addEntryOrdered(entry)
            }
        }
        let lineChartDataSets: [LineChartDataSet] = Array(axisToDataSet.values)
        lineChartView.data = LineChartData(dataSets: lineChartDataSets)
        if lineChartView.data!.count > 0 {
            lineChartView.setVisibleXRangeMaximum(3000)
            lineChartView.moveViewToX(((lineChartView.data?.xMax ?? 1) - 1))
            updateDataLabels()
        }
        axisToData = [:]
    }

    func setupSensorMenu() {
        LogNotify.log("Setting up Sensor Menu")
        var sensors: [UIAction] = []
        for sensor in dataController.getAvailableSensors() {
            let isDefault = (sensor.calliopeService == chart?.sensorType)
            sensors.append(
                UIAction(title: sensor.name, state: isDefault ? .on : .off) { _ in
                    DispatchQueue.main.async {
                        self.resetLineChartView(sensor: sensor)
                    }
                })
        }
        self.sensor = SensorUtility.serviceSensorMap[chart?.sensorType ?? .accelerometer]

        if sensors.isEmpty {
            sensorTypeButton.isEnabled = false
            if let count = lineChartView.data?.count, count > 1 {
                sensors.append(
                    UIAction(title: self.sensor!.name, state: .on) { _ in
                    })
            } else {
                sensors.append(
                    UIAction(title: NSLocalizedString("No Sensor Available", comment: "")) { _ in
                    })
            }
        } else {
            sensors.append(
                UIAction(title: NSLocalizedString("Select", comment: ""), state: .on) { _ in
                })
        }

        var axisButtonChildren: [UIAction] = []
        if axisToDataSet.keys.count > 1 {
            axisButtonChildren.append(
                UIAction(title: NSLocalizedString("All", comment: "")) { _ in
                    guard let dataSets = self.lineChartView.data?.dataSets else {
                        return
                    }
                    for dataSet in dataSets {
                        dataSet.visible = true
                    }
                    self.lineChartView.notifyDataSetChanged()
                    self.updateDataLabels()
                })
        } else if axisToDataSet.keys.isEmpty {
            axisButtonChildren.append(
                UIAction(title: "-") { _ in
                    guard let dataSets = self.lineChartView.data?.dataSets else {
                        return
                    }
                    for dataSet in dataSets {
                        dataSet.visible = true
                    }
                    self.lineChartView.notifyDataSetChanged()
                    self.updateDataLabels()
                    self.lineChartView.notifyDataSetChanged()
                })
        }
        for key in axisToDataSet.keys {
            axisButtonChildren.append(
                UIAction(title: key) { _ in
                    guard let dataSets = self.lineChartView.data?.dataSets else {
                        return
                    }
                    for dataSet in dataSets {
                        dataSet.visible = false
                    }
                    self.lineChartView.lineData?.getLineChartDataSetForLabel(key)?.visible = true
                    self.lineChartView.notifyDataSetChanged()
                })
        }
        sensorAxisButton.menu = UIMenu(title: NSLocalizedString("Axis", comment: ""), children: axisButtonChildren)
        sensorTypeButton.menu = UIMenu(title: NSLocalizedString("Sensors", comment: ""), children: sensors)
    }

    private func resetLineChartView(sensor: Sensor) {
        self.sensor = sensor
        self.lineChartView.data?.clearValues()
        self.lineChartView.data = []
        guard let chart = chart else {
            return
        }
        Chart.deleteChart(id: chart.id)
        self.chart = Chart.insertChart(sensorType: sensor.calliopeService, projectsId: chart.projectsId)
        lineChartView.setupView(service: sensor.calliopeService)
    }

    func updateDataLabels() {
        DispatchQueue.main.async {
            guard let lineChartData = self.lineChartView.data, let lineChartDataSets = lineChartData.dataSets as? [LineChartDataSet], let lineChartDataSet = lineChartDataSets.first else {
                return
            }
            if lineChartDataSets.count > 1 {
                self.avgValueLabel.text = " - "
                self.currentValueLabel.text = " - "
            } else {
                self.avgValueLabel.text = "\(lineChartDataSet.calculateAverageValue().rounded(toPlaces: 2))"
                guard let value = lineChartDataSet.last?.y else {
                    return
                }
                self.currentValueLabel.text = "\(value.rounded(toPlaces: 2))"
            }
            self.maxValueLabel.text = "\(lineChartData.yMax.rounded(toPlaces: 2))"
            self.minValueLabel.text = "\(lineChartData.yMin.rounded(toPlaces: 2))"
        }
    }
}
