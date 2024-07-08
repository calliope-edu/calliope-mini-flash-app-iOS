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
    var timestep = 1.0
    var isRecordingData: Bool = false
    var hasDefaultValues: Bool = false
    
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
    
    required init?(coder: NSCoder) {
        dataController = DataController()
        super.init(coder: coder)
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
        guard let _ = sensor else {
            let alertController = UIAlertController(title: "No Sensor selected or connected", message: nil, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in }
            alertController.addAction(okAction)
            self.inputViewController?.parent?.present(alertController, animated: true, completion: nil)
            return
        }
        
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
    
}
