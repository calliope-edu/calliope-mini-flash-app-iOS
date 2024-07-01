//
//  ChartViewCell.swift
//  Calliope App
//
//  Created by itestra on 27.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import DGCharts

protocol ChartCellDelegate {
    func deleteChart(of cell: ChartViewCell, chart: Chart?)
}

class ChartViewCell: UICollectionViewCell, ChartViewDelegate {
    
    var chart: Chart?
    var lineChartDataSet: LineChartDataSet?
    var lineChartData: LineChartData?
    var sensor: Sensor?
    var timestep = 1.0
    var isRecordingData: Bool = false
    var calliope: Calliope?
    
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var recordingButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var sensorTypeMenu: UIMenu!
    @IBOutlet weak var sensorTypeButton: ContextMenuButton!
    @IBOutlet weak var maxValueLabel: UILabel!
    @IBOutlet weak var minValueLabel: UILabel!
    @IBOutlet weak var avgValueLabel: UILabel!
    @IBOutlet weak var currentValueLabel: UILabel!
    
    public var delegate: ChartCellDelegate!
    public var dataController: DataController
    
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    
    required init?(coder: NSCoder) {
        dataController = DataController()
        super.init(coder: coder)
    }
    
    func setupChartView() {
        deleteButton.setTitle("", for: .normal)
        setupChart()
        setDataLabelValues()
        
        calliopeConnectedSubcription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDDevice.usageReadyNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.recordingButton.isEnabled = true
                    self?.sensorTypeButton.isEnabled = true
                    self?.setupSensorMenu()
                }
        })
        
        calliopeDisconnectedSubscription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDDevice.disconnectedNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.recordingButton.isEnabled = false
                    self?.sensorTypeButton.isEnabled = false
                    self?.stopDataRecording()
                }
        })
        
        setupSensorMenu()
        
        guard let calliope = MatrixConnectionViewController.instance.usageReadyCalliope else {
            recordingButton.isEnabled = false
            sensorTypeButton.isEnabled = false
            return
        }
        self.calliope = calliope
    }
    
    func setupChart() {
        lineChartDataSet = layoutLineChartDataSet(LineChartDataSet()) // vertical line color
        let lineChartData = LineChartData(dataSet: lineChartDataSet ?? LineChartDataSet())
        lineChartData.setDrawValues(false)
        layoutLineChartView()
        lineChartView.data = lineChartData
        guard let rawChartData = Value.fetchValuesBy(chartId: chart?.id), !rawChartData.isEmpty else {
            sensorTypeButton.isEnabled = true
            addDataEntriesToChart(values: [0])
            return
        }
        sensorTypeButton.isEnabled = false
        addDataEntriesToChart(values: rawChartData.compactMap({ value in
            value.value
        }))
    }
    
    fileprivate func layoutLineChartDataSet(_ lineChartDataSet: LineChartDataSet) -> LineChartDataSet{
        lineChartDataSet.setColor(.calliopeGreen)
        lineChartDataSet.lineWidth = 3
        lineChartDataSet.mode = .linear
        lineChartDataSet.drawValuesEnabled = false
        lineChartDataSet.drawCirclesEnabled = false
        lineChartDataSet.drawFilledEnabled = false
        
        lineChartDataSet.drawHorizontalHighlightIndicatorEnabled = false
        lineChartDataSet.highlightLineWidth = 2
        lineChartDataSet.highlightColor = .calliopeGreen
        return lineChartDataSet
    }
    
    fileprivate func layoutLineChartView() {
        lineChartView.xAxis.enabled = false
        lineChartView.xAxis.drawGridLinesEnabled = false
        lineChartView.xAxis.drawLabelsEnabled = false
        
        lineChartView.leftAxis.enabled = true
        lineChartView.leftAxis.drawGridLinesEnabled = true
        lineChartView.leftAxis.drawLabelsEnabled = true
        lineChartView.leftAxis.zeroLineWidth = 3
        
        lineChartView.rightAxis.enabled = false
        lineChartView.rightAxis.drawGridLinesEnabled = true
        lineChartView.rightAxis.drawLabelsEnabled = true
        
        lineChartView.drawGridBackgroundEnabled = false
        lineChartView.legend.enabled = false
        lineChartView.drawBordersEnabled = true
        lineChartView.minOffset = 20
        lineChartView.delegate = self
        lineChartView.backgroundColor = .white
        lineChartView.borderColor = .white
    }
    
    func setupSensorMenu() {
        var sensors : [UIAction] = []
        for sensor in dataController.getAvailableSensors() {
            let isDefault = (sensor.calliopeService == chart?.sensorType)
            sensors.append(UIAction(title: sensor.name, state: isDefault ? .on : .off) { _ in
                self.resetLineChartView(sensor: sensor)
            })
        }
        self.sensor = SensorUtility.serviceSensorMap[chart?.sensorType ?? .accelerometer]
        
        if sensors.isEmpty {
            sensorTypeButton.isEnabled = false
            if let count = lineChartView.data?.count, count > 0 {
                sensors.append(UIAction(title: self.sensor!.name, state: .on) { _ in })
            } else {
                sensors.append(UIAction(title: "No Sensor Available") { _ in })
            }
        } else {
            sensorTypeButton.isEnabled = true
        }
        
        sensorTypeButton.menu = UIMenu(title: "Sensors", children: sensors)
    }
    
    private func resetLineChartView(sensor: Sensor) {
        self.sensor = sensor
        self.lineChartData?.clearValues()
        self.lineChartDataSet = nil
        guard let chart = chart else {
            return
        }
        Chart.deleteChart(id: chart.id)
        self.chart = Chart.insertChart(sensorType: sensor.calliopeService, projectsId: chart.projectsId)
        self.setupChart()
        self.timestep = 1.0
    }
    
    func addDataEntriesToChart(values: [Double]) {
        for value in values {
            let dataEntry = ChartDataEntry(x: timestep, y: value)
            lineChartDataSet?.append(dataEntry)
            timestep += 1
        }
        lineChartView.data?.notifyDataChanged()
        lineChartView.notifyDataSetChanged()
        
        if let lineChartDataSet = self.lineChartDataSet, !lineChartDataSet.isEmpty {
            lineChartView.setVisibleXRangeMaximum(300)
            lineChartView.moveViewToX(Double(lineChartDataSet.count-1))
        }
    }
    
    @IBAction func startRecording(_ sender: Any) {
        sensorTypeButton.isEnabled = false
        deleteButton.isEnabled = false
        startDataRecording()
    }
    
    func startDataRecording() {
        if isRecordingData {
            stopDataRecording()
            return
        }
        guard let selectedSensor = sensor else {
            let alertController = UIAlertController(title: "No Sensor selected or connected", message: nil, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in }
            alertController.addAction(okAction)
            self.inputViewController?.parent?.present(alertController, animated: true, completion: nil)
            return
        }
        dataController.sensorStartRecording(sensor: selectedSensor) { value in
            let newValue = Double(value)
            Value.insertValue(value: newValue, timeStep: self.timestep, chartsId: (self.chart?.id)!)
            self.addDataEntriesToChart(values: [newValue])
            self.setDataLabelValues()
            self.timestep += 1
            self.currentValueLabel.text = "\(newValue.rounded(toPlaces: 2))"
        }
        recordingButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        isRecordingData = true
    }
    
    func stopDataRecording() {
        dataController.sensorStopRecording(sensor: sensor)
        isRecordingData = false
        deleteButton.isEnabled = true
        recordingButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        currentValueLabel.text = ""
    }
    
    @IBAction func deleteChartView(_ sender: Any) {
        stopDataRecording()
        delegate.deleteChart(of: self, chart: chart)
        lineChartDataSet?.removeAll()
    }
    
    func setDataLabelValues() {
        guard let lineChartDataSet = lineChartDataSet, !lineChartDataSet.isEmpty else {
            minValueLabel.text = "0.0"
            maxValueLabel.text = "0.0"
            avgValueLabel.text = "0.0"
            return
        }
        
        minValueLabel.text = "\(lineChartDataSet.yMin.rounded(toPlaces: 2))"
        maxValueLabel.text = "\(lineChartDataSet.yMax.rounded(toPlaces: 2))"
        avgValueLabel.text = "\(lineChartDataSet.calculateAverageValue().rounded(toPlaces: 2))"
    }

    deinit {
        NotificationCenter.default.removeObserver(calliopeConnectedSubcription!)
        NotificationCenter.default.removeObserver(calliopeDisconnectedSubscription!)
    }
}

extension LineChartDataSet {
    func calculateAverageValue() -> Double {
        let yValues = self.entries.map { $0.y }
        let sum = yValues.reduce(0, +)
        return sum / Double(yValues.count)
    }
}

extension Double {
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

class ContextMenuButton: UIButton {
    var previewProvider: UIContextMenuContentPreviewProvider?
    var actionProvider: UIContextMenuActionProvider?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setup() {
        let interaction = UIContextMenuInteraction(delegate: self)
        addInteraction(interaction)
    }

    public override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: previewProvider,
            actionProvider: actionProvider
        )
    }
}
