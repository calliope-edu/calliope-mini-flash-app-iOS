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
    func deleteChart(of cell: ChartViewCell, chart: Chart?)
}

class ChartViewCell: UICollectionViewCell, ChartViewDelegate {
    
    var chart: Chart?
    
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var recordingButton: UIButton!
    
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var sensorTypeMenu: UIMenu!
    @IBOutlet weak var sensorTypeButton: ContextMenuButton!
    @IBOutlet weak var maxValueLabel: UILabel!
    @IBOutlet weak var minValueLabel: UILabel!
    @IBOutlet weak var avgValueLabel: UILabel!
    
    var lineChartDataSet: LineChartDataSet?
    var lineChartData: LineChartData?
    var sensor: Sensor?
    var timeIter = 1.0
    var isRecording: Bool = false
    
    public var delegate: ChartCellDelegate!
    public var dataController: DataController
    
    required init?(coder: NSCoder) {
        dataController = DataController()
        super.init(coder: coder)
    }
    
    func setupChartView() {
        setupSensorMenu()
        deleteButton.setTitle("", for: .normal)
        setupChart()
        setLabelValues()
    }
    
    func setupChart() {
        lineChartDataSet = layoutLineChartDataSet(LineChartDataSet()) // vertical line color
        let lineChartData = LineChartData(dataSet: lineChartDataSet ?? LineChartDataSet())
        lineChartData.setDrawValues(false)
        layoutLineChartView()
        lineChartView.data = lineChartData
        guard let rawChartData = Value.fetchValueforChart(chartId: chart?.id), rawChartData.isEmpty else {
            addDatapoint(values: [0])
            return
        }
        addDatapoint(values: [0])
        addDatapoint(values: rawChartData.compactMap({ value in
            value.value
        }))
    }
    
    fileprivate func layoutLineChartDataSet(_ lineChartDataSet: LineChartDataSet) -> LineChartDataSet{
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
        return lineChartDataSet
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
        //remove artifacts around chart area
        lineChartView.drawBordersEnabled = true
        lineChartView.minOffset = 20
        //setting up delegate needed for touches handling
        lineChartView.delegate = self
        lineChartView.backgroundColor = .white
        lineChartView.borderColor = .white
    }
    
    fileprivate func clearView() {
        self.lineChartData?.clearValues()
        self.lineChartDataSet = nil
        guard let chart = chart else {
            return
        }
        Chart.deleteChart(id: chart.id)
        self.chart = Chart.insertChart(sensorType: sensor?.calliopeService ?? .accelerometer, projectsId: chart.projectsId)
    }
    
    func setupSensorMenu() {
        var elements : [UIAction] = []
        for element in dataController.getAvailableSensors() {
            let isDefault = (element.calliopeService == chart?.sensorType)
            elements.append(UIAction(title: element.name, state: isDefault ? .on : .off) { _ in
                self.sensor = element
                self.clearView()
                self.setupChart()
                self.timeIter = 1.0
            })
        }
        //TODO: Hier noch vernünftigen Standard setzen
        self.sensor = SensorUtility.serviceSensorMap[chart?.sensorType ?? .accelerometer]
        
        if elements.isEmpty {
            elements.append(UIAction(title: "NO SENSORS AVAILABLE") { _ in print("NO ACTION") })
        }
        
        let menu = UIMenu(title: "Available Sensors", children: elements)
        if #available(iOS 14.0, *) {
            sensorTypeButton.menu = menu
        } else {
            // Fallback on earlier versions
        }
    }
    
    func addDatapoint(values: [Double]) {
        for value in values {
            let dataEntry = ChartDataEntry(x: timeIter, y: value)
            lineChartDataSet?.append(dataEntry)
            timeIter += 1
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
        sensorStartRecording()
    }
    
    func sensorStartRecording() {
        if isRecording {
            sensorStopRecording()
            return
        }
        guard let selectedSensor = sensor else { return }
        dataController.sensorStartRecording(sensor: selectedSensor) { value in
            let newValue = Double(value)
            Value.insertValue(value: newValue, timeStep: self.timeIter, chartsId: (self.chart?.id)!)
            self.addDatapoint(values: [newValue])
            self.setLabelValues()
            self.timeIter += 1
        }
        recordingButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        isRecording = true
    }
    
    func sensorStopRecording() {
        dataController.sensorStopRecording(sensor: sensor)
        isRecording = false
        deleteButton.isEnabled = true
        recordingButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
    }
    
    @IBAction func removeChartView(_ sender: Any) {
        sensorStopRecording()
        delegate.deleteChart(of: self, chart: chart)
        lineChartDataSet?.removeAll()
    }
    
    func setLabelValues() {
        guard let lineChartDataSet = lineChartDataSet, !lineChartDataSet.isEmpty else {
            minValueLabel.text = "0.0"
            maxValueLabel.text = "0.0"
            avgValueLabel.text = "0.0"
            return
        }
        minValueLabel.text = "\(lineChartDataSet.yMin.rounded(toPlaces: 2))"
        maxValueLabel.text = "\(lineChartDataSet.yMax.rounded(toPlaces: 2))"
        avgValueLabel.text = "\(calculateAverageValue(of: lineChartDataSet).rounded(toPlaces: 2))"
    }
}

func calculateAverageValue(of dataSet: LineChartDataSet) -> Double {
        let yValues = dataSet.entries.map { $0.y }
        let sum = yValues.reduce(0, +)
        return sum / Double(yValues.count)
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
        if #available(iOS 14.0, *) {
            let interaction = UIContextMenuInteraction(delegate: self)
            addInteraction(interaction)
        } else {
            //TODO: Context Menu for older IOS versions
            // Fallback on earlier versions
        }
    }

    public override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: previewProvider,
            actionProvider: actionProvider
        )
    }
}
