//
//  ChartViewCell.swift
//  Calliope App
//
//  Created by itestra on 27.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import DGCharts
import Foundation
import UIKit
import CoreLocation

class ChartViewCell: BaseChartViewCell {

    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setupCellView() {
        guard let chart = chart else {
            LogNotify.log("Setup of chart failed, no chart has been set")
            return
        }
        lineChartView.setupView(service: chart.sensorType ?? .empty)
        addNotificationSubscriptions()
        loadDatabaseDataIntoChart(chart)
        setupSensorMenu()
        addInteraction(UIContextMenuInteraction(delegate: self))

        guard let _ = MatrixConnectionViewController.instance.usageReadyCalliope else {
            recordingButton.isEnabled = false
            sensorTypeButton.isEnabled = false
            return
        }
    }

    private func exportAsCSV() {
        guard let chart = chart else { return }
        let values = Value.fetchValuesBy(chartId: chart.id)
        guard !values.isEmpty else { return }

        var allKeys: [String] = []
        for value in values {
            let decoded = DataParser.decode(data: value.value, service: chart.sensorType ?? .empty)
            for key in decoded.keys where !allKeys.contains(key) { allKeys.append(key) }
        }
        allKeys.sort()

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm:ss"
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "dd/MM/yy"

        var lines = ["date,time," + allKeys.joined(separator: ",")]
        for value in values {
            let date = Date(timeIntervalSinceReferenceDate: value.time / 100.0)
            let decoded = DataParser.decode(data: value.value, service: chart.sensorType ?? .empty)
            let cols = allKeys.map { decoded[$0].map { String($0) } ?? "" }
            lines.append("\(dateFmt.string(from: date)),\(timeFmt.string(from: date)),\(cols.joined(separator: ","))")
        }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sensor_\(chart.id ?? 0).csv")
        do {
            try lines.joined(separator: "\n").write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            LogNotify.log("Failed to write CSV: \(error)")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = self.bounds
        }
        nearestViewController()?.present(activityVC, animated: true)
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }

    deinit {
        NotificationCenter.default.removeObserver(calliopeConnectedSubcription!)
        NotificationCenter.default.removeObserver(calliopeDisconnectedSubscription!)
    }
}

extension ChartViewCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self else { return nil }
            let export = UIAction(
                title: NSLocalizedString("Export as CSV", comment: ""),
                image: UIImage(systemName: "square.and.arrow.up")
            ) { [weak self] _ in
                self?.exportAsCSV()
            }
            let delete = UIAction(
                title: NSLocalizedString("Delete", comment: ""),
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                guard let self = self else { return }
                self.stopDataRecording()
                self.delegate.deleteChart(of: self, chart: self.chart)
            }
            return UIMenu(title: "", children: [export, delete])
        }
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        // no-op
    }
}

extension ChartViewCell {
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
                if let baseTime = baseTime {
                    lineChartView.xAxis.valueFormatter = TimeAxisValueFormatter(baseTime: baseTime)
                }
            }
            for value in rawValues {
                let decodedValue = DataParser.decode(data: value.value, service: chart.sensorType ?? .empty)
                getDataEntries(data: decodedValue, timestep: value.time, service: chart.sensorType ?? .empty)
                handleLocationData(CLLocationCoordinate2D(latitude: value.lat, longitude: value.long), value.time)
            }
            addDataEntries(dataEntries: axisToData)
            
            sensorTypeButton.isEnabled = false
            recordingButton.isEnabled = false
        } else {
            sensorTypeButton.isEnabled = true
            recordingButton.isEnabled = (chart.sensorType != nil)
        }
    }

    @IBAction func deleteChartView(_ sender: Any) {
        stopDataRecording()
        delegate.deleteChart(of: self, chart: chart)
    }

    func chartValueSelected(
        _ chartView: ChartViewBase,
        entry: ChartDataEntry,
        highlight: Highlight
    ) {
        self.currentValueLabel.text = String(entry.y.rounded(toPlaces: 2))
    }

}

extension LineChartDataSet {
    func calculateAverageValue() -> Double {
        let yValues = self.entries.map {
            $0.y
        }
        let sum = yValues.reduce(0, +)
        return sum / Double(yValues.count)
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
        showsMenuAsPrimaryAction = true
    }
}
