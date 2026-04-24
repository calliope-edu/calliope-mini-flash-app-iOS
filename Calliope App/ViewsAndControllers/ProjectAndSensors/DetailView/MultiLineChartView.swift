//
//  MultiLineChartView.swift
//  Calliope App
//
//  Created by Calliope on 24.04.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

struct ChartScale {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    
    func stepValues(steps: Int) -> [Double] {
        (0...steps).map { i in
            let t = Double(i) / Double(steps)
            return maxY - t * (maxY - minY)
        }
    }
    
    func yPosition(value: Double, height: CGFloat) -> CGFloat {
        let range = maxY - minY
        guard range != 0 else { return height / 2 }
        return height - CGFloat((value - minY) / range) * height
    }
    
    func yPositions(steps: Int, height: CGFloat) -> [CGFloat] {
        stepValues(steps: steps).map { yPosition(value: $0, height: height) }
    }
    
    func xPosition(value: Double, width: CGFloat) -> CGFloat {
        let range = maxX - minX
        guard range != 0 else { return width / 2 }
        return CGFloat((value - minX) / range) * width
    }
}

struct MultiLineChartView: View {
    @Binding var dataSets: [String: [DataPoint]]
    let yAxisSteps: Int = 5
    
    let colors = [
        Color.red,
        Color.blue,
        Color.green,
        Color.orange,
        Color.purple,
        Color.brown,
        Color.teal,
        Color.pink
    ]
    
    // Extract Y values for scale calculation
    private var allYValues: [Double] {
        dataSets.values.flatMap { $0.map { $0.y } }
    }
    
    // Extract X values for scale calculation
    private var allXValues: [Double] {
        dataSets.values.flatMap { $0.map { $0.x } }
    }
    
    private var scale: ChartScale {
        ChartScale(
            minX: allXValues.min() ?? 0,
            maxX: allXValues.max() ?? 1,
            minY: allYValues.min() ?? 0,
            maxY: allYValues.max() ?? 1
        )
    }
    
    var body: some View {
        let chartHeight: CGFloat = 250
        HStack(spacing: 8) {
            // MARK: Y Axis
            GeometryReader { geo in
                let positions = scale.yPositions(steps: yAxisSteps, height: chartHeight)
                ZStack {
                    ForEach(0..<positions.count, id: \.self) { i in
                        Text(String(format: "%.0f", scale.stepValues(steps: yAxisSteps)[i]))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .position(x: geo.size.width / 2, y: positions[i])
                    }
                }
            }
            .frame(width: 40, height: chartHeight)
            
            // MARK: Chart Area
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let gridY = scale.yPositions(steps: yAxisSteps, height: height)
                
                ZStack {
                    Color.white
                    
                    // Grid
                    ForEach(gridY, id: \.self) { y in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    }
                    
                    // Lines
                    ForEach(Array(dataSets.values).enumerated(), id: \.offset) { index, data in
                        Path { path in
                            guard data.count > 1 else { return }
                            
                            // Start at first point
                            let firstX = scale.xPosition(value: data[0].x, width: width)
                            let firstY = scale.yPosition(value: data[0].y, height: height)
                            path.move(to: CGPoint(x: firstX, y: firstY))
                            
                            // Draw lines to subsequent points
                            for i in 1..<data.count {
                                let x = scale.xPosition(value: data[i].x, width: width)
                                let y = scale.yPosition(value: data[i].y, height: height)
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(colors[index % colors.count], lineWidth: 1.5)
                    }
                }
            }
            .frame(height: chartHeight)
        }
        .frame(height: chartHeight)
        .padding()
        .background(Color.white)
    }
}
