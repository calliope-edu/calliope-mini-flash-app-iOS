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
        lineChartView.delegate = self
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
    
    fileprivate func loadDatabaseDataIntoChart(_ chart: Chart) {
        LogNotify.log("Starting to load existing Data into Chart")
        let rawValues = Value.fetchValuesBy(chartId: chart.id)
        if !rawValues.isEmpty {
            if baseTime == nil {
                baseTime = rawValues.first?.time
            }
            for value in rawValues {
                let decodedValue = DataParser.decode(data: value.value, service: chart.sensorType)
                getDataEntries(data: decodedValue, timestep: value.time, service: chart.sensorType)
            }
            addDataEntries(dataEntries: axisToData)
            
            sensorTypeButton.isEnabled = false
            recordingButton.isEnabled = false
        }
    }
    
    @IBAction func deleteChartView(_ sender: Any) {
        stopDataRecording()
        delegate.deleteChart(of: self, chart: chart)
    }
    
    override func chartValueSelected(
        _ chartView: ChartViewBase,
        entry: ChartDataEntry,
        highlight: Highlight
    ) {
        self.currentValueLabel.text = String(entry.y.rounded(toPlaces: 2))
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
