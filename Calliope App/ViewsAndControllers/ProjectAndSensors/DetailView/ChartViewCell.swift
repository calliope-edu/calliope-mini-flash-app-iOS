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
    var sensor: Sensor?
    var timestep = 1.0
    var isRecordingData: Bool = false
    var calliope: Calliope?
    
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var recordingButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var sensorTypeMenu: UIMenu!
    @IBOutlet weak var sensorTypeButton: ContextMenuButton!
    @IBOutlet weak var sensorAxisMenu: UIMenu!
    @IBOutlet weak var sensorAxisButton: ContextMenuButton!
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
        guard let chart = chart else {
            LogNotify.log("Setup of chart failed, no chart has been set")
            return
        }
        lineChartView.setupView(service: chart.sensorType)
        addNotificationSubscriptions()
        loadDatabaseDataIntoChart(chart)
        setupSensorMenu()
        
        guard let calliope = MatrixConnectionViewController.instance.usageReadyCalliope else {
            recordingButton.isEnabled = false
            sensorTypeButton.isEnabled = false
            return
        }
        self.calliope = calliope
    }
    
    fileprivate func addNotificationSubscriptions() {
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
    }
    
    fileprivate func setDefaultChartValues() {
        var entries = [ChartDataEntry(x: timestep, y: 0), ChartDataEntry(x: timestep, y: 0), ChartDataEntry(x: timestep, y: 0)]
        addDataEntries(dataEntries: [entries])
        timestep += 1
    }
    
    fileprivate func loadDatabaseDataIntoChart(_ chart: Chart) {
        LogNotify.log("Starting to load existing Data into Chart")
        let rawValues = Value.fetchValuesBy(chartId: chart.id)
        var initialDataEntries: [[ChartDataEntry]] = []
        if !rawValues.isEmpty {
            print(rawValues.count)
            for value in rawValues {
                let decodedValue = DataParser.decode(data: value.value, service: chart.sensorType)
                initialDataEntries.append(getDataEntries(data: decodedValue, service: chart.sensorType))
            }
            addDataEntries(dataEntries: initialDataEntries)
        } else {
            setDefaultChartValues()
        }
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
            if let dataSets = lineChartView.data!.dataSets as? [ChartDataSet], dataSets[0].count > 1 {
                sensorTypeButton.isEnabled = false
            } else {
                sensorTypeButton.isEnabled = true
            }
        }
        
        sensorAxisButton.menu = UIMenu(title: "Axis", children: [
            UIAction(title: "XYZ") { _ in
                self.lineChartView.data?.dataSets[0].visible = true
                self.lineChartView.data?.dataSets[1].visible = true
                self.lineChartView.data?.dataSets[2].visible = true
                self.lineChartView.notifyDataSetChanged()
            },
            UIAction(title: "X") { _ in
                self.lineChartView.data?.dataSets[0].visible = true
                self.lineChartView.data?.dataSets[1].visible = false
                self.lineChartView.data?.dataSets[2].visible = false
                self.lineChartView.notifyDataSetChanged()
            },
            UIAction(title: "Y") { _ in
                self.lineChartView.data?.dataSets[0].visible = false
                self.lineChartView.data?.dataSets[1].visible = true
                self.lineChartView.data?.dataSets[2].visible = false
                self.lineChartView.notifyDataSetChanged()
            },
            UIAction(title: "Z") { _ in
                self.lineChartView.data?.dataSets[0].visible = false
                self.lineChartView.data?.dataSets[1].visible = false
                self.lineChartView.data?.dataSets[2].visible = true
                self.lineChartView.notifyDataSetChanged()
            }
        ])
        
        if chart?.sensorType == .accelerometer {
            sensorAxisButton.isHidden = false
        } else {
            sensorAxisButton.isHidden = true
        }
        sensorTypeButton.menu = UIMenu(title: "Sensors", children: sensors)
    }
    
    private func resetLineChartView(sensor: Sensor) {
        self.sensor = sensor
        self.lineChartView.data!.clearValues()
        self.lineChartView.data = []
        guard let chart = chart else {
            return
        }
        Chart.deleteChart(id: chart.id)
        self.chart = Chart.insertChart(sensorType: sensor.calliopeService, projectsId: chart.projectsId)
        lineChartView.setupView(service: sensor.calliopeService)
        setDefaultChartValues()
        self.timestep = 1.0
        
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
    
    @IBAction func startRecording(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.sensorTypeButton.isEnabled = false
            self.deleteButton.isEnabled = false
            self.recordingButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
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
        
        guard let chart = chart else {
            fatalError("chart has not been initialized before using the ChartViewCell")
        }
        dataController.sensorStartRecordingFor(chart: chart) { value in
            if self.isRecordingData {
                guard let chart = self.chart else {
                    fatalError()
                }
                self.addDataEntries(dataEntries:  [self.getDataEntries(data: value, service: chart.sensorType)])
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
            self.recordingButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        }
    }
    
    @IBAction func deleteChartView(_ sender: Any) {
        stopDataRecording()
        delegate.deleteChart(of: self, chart: chart)
    }
    
    func getDataEntries(data: Any, service: CalliopeService) -> [ChartDataEntry] {
        var entriesToAdd: [ChartDataEntry] = []
        switch service {
        case .accelerometer:
            let typedData = data as! (Double, Double, Double)
            entriesToAdd.append(ChartDataEntry(x: timestep, y: typedData.0))
            entriesToAdd.append(ChartDataEntry(x: timestep, y: typedData.1))
            entriesToAdd.append(ChartDataEntry(x: timestep, y: typedData.2))
        default:
            let typedData = data as! Double
            entriesToAdd.append(ChartDataEntry(x: timestep, y: typedData))
        }
        timestep += 1
        return entriesToAdd
    }
    
    func addDataEntries(dataEntries: [[ChartDataEntry]]) {
        for entry in dataEntries {
            for index in 0...lineChartView.data!.dataSets.count-1 {
                _ = lineChartView.data![index].addEntry(entry[index])
            }
        }
        lineChartView.data?.notifyDataChanged()
        lineChartView.notifyDataSetChanged()
        
        if lineChartView.data!.count > 0 {
            lineChartView.setVisibleXRangeMaximum(300)
            lineChartView.moveViewToX(timestep-1)
            updateDataLabels()
        }
    }

    func updateDataLabels() {
        DispatchQueue.main.async {
            self.minValueLabel.text = String((self.lineChartView.data?.yMin.rounded(toPlaces: 2))!)
            self.maxValueLabel.text = String((self.lineChartView.data?.yMax.rounded(toPlaces: 2))!)
            if self.chart?.sensorType == .accelerometer {
                self.avgValueLabel.text = "-"
                self.currentValueLabel.text = "-"
            } else {
                guard let dataSet = self.lineChartView.data!.dataSets[0] as? LineChartDataSet else {
                    self.avgValueLabel.text = "-"
                    self.currentValueLabel.text = "-"
                    return
                }
                self.currentValueLabel.text = String(dataSet.last!.x.rounded(toPlaces: 2))
                self.avgValueLabel.text = String(dataSet.calculateAverageValue().rounded(toPlaces: 2))
            }
        }
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
