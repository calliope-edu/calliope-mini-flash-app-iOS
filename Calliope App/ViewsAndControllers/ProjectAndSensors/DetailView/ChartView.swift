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
        self.xAxis.enabled = true
        self.xAxis.drawGridLinesEnabled = false
        self.xAxis.drawLabelsEnabled = true
        self.xAxis.labelPosition = .bottom
        self.xAxis.granularityEnabled = true
        self.xAxis.granularity = 1000  // label every 10 seconds
        self.xAxis.labelRotationAngle = 0

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
        self.backgroundColor = .white
        self.borderColor = .white
        self.drawMarkers = true
    }

    func setupView(service: CalliopeService) {
        self.data?.clearValues()
        self.notifyDataSetChanged()
        self.layoutChartView()
    }
}

class TimeAxisValueFormatter: AxisValueFormatter {
    private let baseTime: Double
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init(baseTime: Double) {
        self.baseTime = baseTime
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSinceReferenceDate: (value + baseTime) / 100.0)
        return formatter.string(from: date)
    }
}

extension LineChartDataSet {
    func layoutDataSet(color: NSUIColor) -> LineChartDataSet {
        self.setColor(color)
        self.lineWidth = 3
        self.mode = .linear
        self.drawValuesEnabled = false
        self.drawCirclesEnabled = false
        self.drawFilledEnabled = false

        self.drawHorizontalHighlightIndicatorEnabled = false
        self.highlightLineWidth = 2
        self.highlightColor = .calliopeGreen
        self.visible = true
        return self
    }
}

extension LineChartData {
    func getLineChartDataSetForLabel(_ label: String) -> LineChartDataSet? {
        for dataSet in self.dataSets {
            if dataSet.label == label {
                return dataSet as? LineChartDataSet
            }
        }
        return nil
    }
}
