//
//  ChartView.swift
//  Calliope App
//
//  Created by itestra on 02.07.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import DGCharts


extension LineChartView {
    
    func layoutChartView() {
        self.xAxis.enabled = false
        self.xAxis.drawGridLinesEnabled = false
        self.xAxis.drawLabelsEnabled = false
        
        self.leftAxis.enabled = true
        self.leftAxis.drawGridLinesEnabled = true
        self.leftAxis.drawLabelsEnabled = true
        self.leftAxis.zeroLineWidth = 3
        
        self.rightAxis.enabled = false
        self.rightAxis.drawGridLinesEnabled = true
        self.rightAxis.drawLabelsEnabled = true
        
        self.drawGridBackgroundEnabled = false
        self.legend.enabled = false
        self.drawBordersEnabled = true
        self.minOffset = 20
        //self.delegate = self
        self.backgroundColor = .white
        self.borderColor = .white
    }
    
    func setupView(service: CalliopeService) {
        var lineChartDataSets: [LineChartDataSet] = []
        switch service {
        case .accelerometer:
            lineChartDataSets.append(LineChartDataSet().layoutDataSet(color: .calliopeGreen))
            lineChartDataSets.append(LineChartDataSet().layoutDataSet(color: .calliopePink))
            lineChartDataSets.append(LineChartDataSet().layoutDataSet(color: .calliopeOrange))
        default:
            lineChartDataSets.append(LineChartDataSet().layoutDataSet(color: .calliopeGreen))
        }
        
        let lineChartData = LineChartData(dataSets: lineChartDataSets)
        lineChartData.setDrawValues(false)
        self.data = lineChartData
        self.layoutChartView()
    }
}

extension LineChartDataSet {
    func layoutDataSet(color: NSUIColor) -> LineChartDataSet{
        self.setColor(color)
        self.lineWidth = 3
        self.mode = .linear
        self.drawValuesEnabled = false
        self.drawCirclesEnabled = false
        self.drawFilledEnabled = false
        
        self.drawHorizontalHighlightIndicatorEnabled = false
        self.highlightLineWidth = 2
        self.highlightColor = .calliopeGreen
        return self
    }
}
