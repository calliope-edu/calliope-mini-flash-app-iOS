//
//  ChartView.swift
//  Calliope App
//
//  Created by itestra on 27.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import DGCharts

protocol ChartCellDelegate {
    func deleteChart(of cell: ChartViewController, chart: Chart?)
}

class ChartViewController: UICollectionViewCell, ChartViewDelegate {
    
    var chart: Chart?
    
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var recordingButton: UIButton!
    
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var sensorTypeMenu: UIMenu!
    @IBOutlet weak var sensorTypeButton: UIButton!
    @IBOutlet weak var maxValueLabel: UILabel!
    @IBOutlet weak var minValueLabel: UILabel!
    @IBOutlet weak var avgValueLabel: UILabel!
    
    var dataEntries: [ChartDataEntry] = []
    var lineChartDataSet: LineChartDataSet?
    var lineChartData: LineChartData?
    var dataEntriesFloat: [Double] = []
    var sensor: Sensor?
    static var timeIter = 1.0
    var timer: Timer?
    var isRecording: Bool = false
    
    public var delegate: ChartCellDelegate!
    
    fileprivate func layoutLineChartDataSet(_ lineChartDataSet: LineChartDataSet) {
        // chart main settings
        lineChartDataSet.setColor(.calliopeGreen)
        lineChartDataSet.lineWidth = 3
        lineChartDataSet.mode = .linear //curve smoothing
        lineChartDataSet.drawValuesEnabled = false //disble values
        lineChartDataSet.drawCirclesEnabled = false //disable circles
        lineChartDataSet.drawFilledEnabled = false // gradient setting
        
        // settings for picking values on graph
        lineChartDataSet.drawHorizontalHighlightIndicatorEnabled = false // leave only vertical line
        lineChartDataSet.highlightLineWidth = 2 // vertical line width
        lineChartDataSet.highlightColor = .calliopeGreen
    }
    
    fileprivate func layoutLineChartView() {
        // disable grid
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
        //disable zoom
        lineChartView.pinchZoomEnabled = false
        lineChartView.doubleTapToZoomEnabled = false
        //remove artifacts around chart area
        lineChartView.drawBordersEnabled = true
        lineChartView.minOffset = 20
        //setting up delegate needed for touches handling
        lineChartView.delegate = self
        lineChartView.backgroundColor = .white
        lineChartView.borderColor = .white
    }
    
    func setChart(values: [Double]) {
        guard let rawChartData = Value.fetchValueforChart(chartId: chart?.id) else {
                return
        }
        for i in 0..<rawChartData.count {
            let dataEntry = ChartDataEntry(x: Double(i), y: rawChartData[i].value)
            dataEntries.append(dataEntry)
        }
        ChartViewController.timeIter = Double(rawChartData.count ?? 0)
        lineChartDataSet = LineChartDataSet(entries: dataEntries)
        
        layoutLineChartDataSet(lineChartDataSet ?? LineChartDataSet()) // vertical line color
        let lineChartData = LineChartData(dataSet: lineChartDataSet ?? LineChartDataSet())
        lineChartData.setDrawValues(false)
        layoutLineChartView()

        lineChartView.data = lineChartData
    }
    
    func addDatapoint(datapoint: ChartDataEntry) {
        lineChartDataSet?.addEntryOrdered(datapoint)
        lineChartView.data = LineChartData(dataSet: lineChartDataSet!)
        lineChartView.animate(xAxisDuration: 0.1)
        lineChartView.notifyDataSetChanged()
    }
    
    func sensorStartRecording() {
        if isRecording {
            sensorStopRecording()
            return
        }
        guard let calliope = MatrixConnectionViewController.instance.usageReadyCalliope else {
            LogNotify.log("Unable to record, due to missing calliope")
            return
        }
        let apiCalliope = calliope as! CalliopeAPI
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            apiCalliope.discoveredOptionalServices
            let newValue = Double(apiCalliope.accelerometerValue!.0)
            Value.insertValue(value: newValue, timeStep: ChartViewController.timeIter, chartsId: (self.chart?.id)!)
            self.addDatapoint(datapoint: ChartDataEntry(x: ChartViewController.timeIter, y: newValue))
            self.dataEntriesFloat.append(newValue)
            self.updateMinMaxLabels()
            ChartViewController.timeIter += 1
        }
        recordingButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        isRecording = true
    }
    
    func sensorStopRecording() {
        timer?.invalidate()
        isRecording = false
        recordingButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
    }
    
    @IBAction func startRecording(_ sender: Any) {
        sensorStartRecording()
    }
    
    @IBAction func removeChartView(_ sender: Any) {
        delegate.deleteChart(of: self, chart: chart)
    }
    
    func updateMinMaxLabels() {
        
        let sumArray = dataEntriesFloat.reduce(0, +)
        let avgArrayValue = sumArray / Double(dataEntriesFloat.count)
        
        minValueLabel.text = "\(dataEntriesFloat.min()?.rounded(toPlaces: 2) ?? 0.0)"
        maxValueLabel.text = "\(dataEntriesFloat.max()?.rounded(toPlaces: 2) ?? 0.0)"
        avgValueLabel.text = "\(avgArrayValue.rounded(toPlaces: 2))"
    }
    
    deinit {
        sensorStopRecording()
    }
}

extension Double {
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
