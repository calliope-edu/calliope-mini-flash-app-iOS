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



class ChartViewCell: BaseChartViewCell {
    
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    
    required init?(coder: NSCoder) {
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
        
        guard let _ = MatrixConnectionViewController.instance.usageReadyCalliope else {
            recordingButton.isEnabled = false
            sensorTypeButton.isEnabled = false
            return
        }
    }
    
    fileprivate func addNotificationSubscriptions() {
        calliopeConnectedSubcription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDDevice.usageReadyNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    LogNotify.log("Received usage ready Notification")
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
        let entries = [ChartDataEntry(x: 1, y: 0), ChartDataEntry(x: 1, y: 0), ChartDataEntry(x: 1, y: 0)]
        addDataEntries(dataEntries: [entries])
        hasDefaultValues = true
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
    
    
    @IBAction func deleteChartView(_ sender: Any) {
        stopDataRecording()
        delegate.deleteChart(of: self, chart: chart)
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
