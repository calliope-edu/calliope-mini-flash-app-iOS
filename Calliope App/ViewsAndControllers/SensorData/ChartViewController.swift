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

class ChartViewController: AutoHeightCollectionViewCell, ChartViewDelegate {
    
    @IBOutlet weak var lineChartView: LineChartView!
    var dataEntries: [ChartDataEntry] = []
    var lineChartDataSet: LineChartDataSet?
    var lineChartData: LineChartData?
    
    fileprivate func layoutLineChartDataSet(_ lineChartDataSet: LineChartDataSet) {
        // chart main settings
        lineChartDataSet.setColor(.calliopeGreen)
        lineChartDataSet.lineWidth = 3
        lineChartDataSet.mode = .cubicBezier // curve smoothing
        lineChartDataSet.drawValuesEnabled = false // disble values
        lineChartDataSet.drawCirclesEnabled = false // disable circles
        lineChartDataSet.drawFilledEnabled = false // gradient setting
        
        // settings for picking values on graph
        lineChartDataSet.drawHorizontalHighlightIndicatorEnabled = false // leave only vertical line
        lineChartDataSet.highlightLineWidth = 2 // vertical line width
        lineChartDataSet.highlightColor = .calliopeGreen
    }
    
    fileprivate func layoutLineChartView() {
        // disable grid
        lineChartView.xAxis.drawGridLinesEnabled = false
        lineChartView.leftAxis.drawGridLinesEnabled = false
        lineChartView.rightAxis.drawGridLinesEnabled = false
        lineChartView.drawGridBackgroundEnabled = false
        // disable axis annotations
        lineChartView.xAxis.drawLabelsEnabled = false
        lineChartView.leftAxis.drawLabelsEnabled = false
        lineChartView.rightAxis.drawLabelsEnabled = false
        // disable legend
        lineChartView.legend.enabled = false
        // disable zoom
        lineChartView.pinchZoomEnabled = false
        lineChartView.doubleTapToZoomEnabled = false
        // remove artifacts around chart area
        lineChartView.xAxis.enabled = true
        lineChartView.leftAxis.enabled = false
        lineChartView.rightAxis.enabled = false
        lineChartView.drawBordersEnabled = false
        lineChartView.minOffset = 20
        // setting up delegate needed for touches handling
        lineChartView.delegate = self
        lineChartView.backgroundColor = .white
    }
    
    func setChart(values: [Double]) {
        for i in 0..<values.count {
            let dataEntry = ChartDataEntry(x: Double(i), y: values[i])
            dataEntries.append(dataEntry)
        }
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
        lineChartView.notifyDataSetChanged()
    }
}
