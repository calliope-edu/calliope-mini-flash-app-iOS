//
//  ChartDataHandler.swift
//  Calliope App
//
//  Created by itestra on 02.07.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import DGCharts

protocol ChartCellDelegate {
    func deleteChart(of cell: ChartViewCell, chart: Chart?)
}

class BaseChartViewCell: UICollectionViewCell, ChartViewDelegate {
    
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
                self.getDataEntries(data: [value.0 : value.2], timestep: value.1, service: chart.sensorType)
                self.addDataEntries(dataEntries:  self.axisToData)
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
            self.recordingButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        }
    }
    
    func getDataEntries(data: [String : Double], timestep: Double, service: CalliopeService) {
        for key in data.keys {
            var dataSet : [ChartDataEntry] = axisToData[key] ?? []
            guard let datapoint = data[key], let baseTime = baseTime else {
                return
            }
            dataSet.append(ChartDataEntry(x: Double(timestep) - baseTime, y: datapoint))
            axisToData[key] = dataSet
        }
    }
    
    func addDataEntries(dataEntries: [String : [ChartDataEntry]]) {
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
        let lineChartDataSets : [LineChartDataSet] = Array(axisToDataSet.values)
        lineChartView.data = LineChartData(dataSets: lineChartDataSets)
        if lineChartView.data!.count > 0 {
            lineChartView.setVisibleXRangeMaximum(300)
            lineChartView.moveViewToX(((lineChartView.data?.xMax ?? 1)  - 1))
            updateDataLabels()
        }
        axisToData = [:]
    }
    
    func setupSensorMenu() {
        LogNotify.log("Setting up Sensor Menu")
        var sensors : [UIAction] = []
        for sensor in dataController.getAvailableSensors() {
            let isDefault = (sensor.calliopeService == chart?.sensorType)
            sensors.append(UIAction(title: sensor.name, state: isDefault ? .on : .off) { _ in
                DispatchQueue.main.async {
                    self.resetLineChartView(sensor: sensor)
                }
            })
        }
        self.sensor = SensorUtility.serviceSensorMap[chart?.sensorType ?? .accelerometer]
        
        if sensors.isEmpty {
            sensorTypeButton.isEnabled = false
            if let count = lineChartView.data?.count, count > 1 {
                sensors.append(UIAction(title: self.sensor!.name, state: .on) { _ in })
            } else {
                sensors.append(UIAction(title: "No Sensor Available") { _ in })
            }
        } else {
            sensors.append(UIAction(title:"Select", state: .on) { _ in })
        }
        
        var axisButtonChildren : [UIAction] = []
        axisButtonChildren.append(UIAction(title: "All") { _ in
            self.lineChartView.notifyDataSetChanged()
            self.selectedAxis = -1
            self.updateDataLabels()
        })
        for key in axisToDataSet.keys {
            axisButtonChildren.append(UIAction(title: key) { _ in
                self.lineChartView.notifyDataSetChanged()
                self.selectedAxis = -1
                self.updateDataLabels()
            })
        }
        sensorAxisButton.menu = UIMenu(title: "Axis", children: axisButtonChildren)
        sensorTypeButton.menu = UIMenu(title: "Sensors", children: sensors)
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
        //setDefaultChartValues()
        
        if sensor.calliopeService == .accelerometer {
            self.sensorAxisButton.alpha = 0.0
            self.sensorAxisButton.isHidden = false
        } else {
            self.sensorAxisButton.alpha = 1.0
        }
        UIView.animate(withDuration: 0.3) {
            if sensor.calliopeService == .accelerometer {
                self.sensorAxisButton.alpha = 1.0
            } else {
                self.sensorAxisButton.alpha = 0.0
            }
        }
        if sensor.calliopeService != .accelerometer {
            self.sensorAxisButton.isHidden = true
        }
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let xValue = entry.x
        let yValue = entry.y
        print("Selected value: x = \(xValue), y = \(yValue)")
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        print("Nothing selected")
    }
    
    func updateDataLabels() {
    }
    
}
