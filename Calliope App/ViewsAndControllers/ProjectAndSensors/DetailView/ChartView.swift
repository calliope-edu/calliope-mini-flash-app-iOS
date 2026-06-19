//
//  ChartView.swift
//  Calliope App
//
//  Created by Calliope on 29.05.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Charts
import Foundation
import SwiftUI

struct ChartView: View {
    @ObservedObject var viewModel: ChartViewModel
    let onRemoveTapped: () -> Void
    @State var showMenu = false

    var body: some View {
        VStack {
            ChartHeaderView(
                viewModel: viewModel,
                onRemoveTapped: onRemoveTapped
            )

            MetricsRowView(viewModel: viewModel)

            LineChart(viewModel: viewModel)

            Slider(value: $viewModel.sliderPosition, in: 0.0...1.0)
        }
        .onLongPressGesture(minimumDuration: 1) {
            showMenu = true
        }
        .confirmationDialog(
            "",
            isPresented: $showMenu,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onRemoveTapped() }
            Button("Export (CSV)") { viewModel.exportAsCSV() }
        }
    }
}

struct LineChart: View {
    @ObservedObject var viewModel: ChartViewModel
    @GestureState var gestureScale: CGFloat = 1.0
    @GestureState var gestureOffset: CGSize = .zero


    var maxRange: ClosedRange<Double> {
        return (viewModel.minimumX ?? 0)...(viewModel.maximumX ?? 1)
    }

    

    fileprivate func zoomGesture(_ geo: GeometryProxy) -> _EndedGesture<
        GestureStateGesture<MagnificationGesture, CGFloat>
    > {
        return MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = 1 / value
                state = min(viewModel.maximumGraphScale / viewModel.currentScale, state)
                state = max(viewModel.minimumGraphScale / viewModel.currentScale, state)
                viewModel.ensureOffsetInBounds(graphWidth: geo.size.width)
                viewModel.updateDisplayedRange(graphWidth: geo.size.width, gestureOffset: gestureOffset, gestureScale: gestureScale)
            }
            .onEnded { value in
                viewModel.currentScale /= value
                viewModel.currentScale = max(viewModel.minimumGraphScale, min(viewModel.maximumGraphScale, viewModel.currentScale))
                viewModel.ensureOffsetInBounds(graphWidth: geo.size.width)
                viewModel.updateDisplayedRange(graphWidth: geo.size.width, gestureOffset: gestureOffset, gestureScale: gestureScale)
            }
    }

    fileprivate func dragGesture(_ geo: GeometryProxy) -> _EndedGesture<
        GestureStateGesture<DragGesture, CGSize>
    > {
        let displayedRangeWidth = viewModel.totalRangeWidth * viewModel.currentScale * gestureScale
        let minimumOffset = (viewModel.minimumX ?? 0) + (displayedRangeWidth / 2)
        let maximumOffset = (viewModel.maximumX ?? 1) - (displayedRangeWidth / 2)
        return DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state.width = -value.translation.width * viewModel.currentScale * gestureScale * (viewModel.totalRangeWidth / geo.size.width)
                state.width = min(maximumOffset - viewModel.currentOffset.width, state.width)
                state.width = max(minimumOffset - viewModel.currentOffset.width, state.width)
                viewModel.updateDisplayedRange(graphWidth: geo.size.width, gestureOffset: gestureOffset, gestureScale: gestureScale)
            }

            .onEnded { value in
                viewModel.currentOffset.width -= value.translation.width * viewModel.currentScale * gestureScale * (viewModel.totalRangeWidth / geo.size.width)
                viewModel.currentOffset.width = max(minimumOffset, min(maximumOffset, viewModel.currentOffset.width))
                viewModel.updateDisplayedRange(graphWidth: geo.size.width, gestureOffset: gestureOffset, gestureScale: gestureScale)
            }
    }

    var body: some View {
        VStack {
            GeometryReader { geo in
                chart
                    .chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading)  // puts the y axis on the left side of the view
                    }
                    .chartYScale(
                        domain: (viewModel.absoluteMinimum ?? 0)...(viewModel
                            .absoluteMaximum ?? 1)
                    )
                    .chartXAxis {
                        axisMarks
                    }
                    .chartXScale(
                        domain: viewModel.displayedRange ?? maxRange
                    )
                    .gesture(
                        SimultaneousGesture(
                            zoomGesture(geo),
                            dragGesture(geo)
                        )
                    )
                    .onAppear {
                        viewModel.currentOffset.width = viewModel.totalRangeWidth / 2  // ensures that it zooms around the center in the beginning
                        viewModel.updateDisplayedRange(graphWidth: geo.size.width, gestureOffset: gestureOffset, gestureScale: gestureScale)
                    }
                    .frame(minHeight: 250)
                    .background(Color.white)
            }
            .frame(minHeight: 250)
        }
        .padding()  // space between chart and container edge
        .background(Color.white)
        .cornerRadius(12)
    }
    
    var axisMarks: AxisMarks<some AxisMark> {
        AxisMarks { value in
            AxisGridLine()
            AxisValueLabel {
                if let timestamp = value.as(Double.self) {
                    Text(
                        TimeAxisValueFormatter.stringForValue(
                            baseTime: viewModel.baseTime
                                ?? 0,
                            timestamp
                        )
                    )
                }
            }
        }
    }

    var chart: some View {
        Charts.Chart {
            ForEach(viewModel.displayedChartData) { dataPoint in
                lineMarker(dataPoint: dataPoint)
            }
            sliderMarker
        }
    }

    func lineMarker(dataPoint: ChartDataPoint) -> some ChartContent {
        let xValue: PlottableValue = .value("Time", dataPoint.x)
        let yValue: PlottableValue = .value(
            dataPoint.series,
            dataPoint.y
        )
        let seriesValue: PlottableValue = .value(
            "Axis",
            dataPoint.series
        )

        return LineMark(
            x: xValue,
            y: yValue,
            series: seriesValue
        )
        .foregroundStyle(
            viewModel.getColorForAxis(axis: dataPoint.series)
        )
    }

    @ChartContentBuilder
    var sliderMarker: some ChartContent {
        if viewModel.displayedRange != nil {
            let displayedRangeWidth = viewModel.displayedRange!.upperBound - viewModel.displayedRange!.lowerBound
            RuleMark(
                x: .value("Time", viewModel.sliderPosition * displayedRangeWidth + viewModel.displayedRange!.lowerBound)
            )

        }
    }
}

struct MetricsRowView: View {
    @ObservedObject var viewModel: ChartViewModel

    var body: some View {
        HStack {
            Spacer()
            MetricView(
                metricName: "Minimum",
                metricValue: viewModel.dislpayedMinimum
            )
            Spacer()
            MetricView(
                metricName: "Average",
                metricValue: viewModel.displayedAverage
            )
            Spacer()
            MetricView(
                metricName: "Maximum",
                metricValue: viewModel.dislpayedMaximum
            )
            Spacer()
            MetricView(
                metricName: "Current",
                metricValue: viewModel.displayedCurrent
            )
            Spacer()
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let series: String
    let location: IdentifiableLocation?
}

struct ChartHeaderView: View {
    @ObservedObject var viewModel: ChartViewModel
    var onRemoveTapped: () -> Void
    @State var showMenu = false

    var body: some View {
        HStack {
            sensorDropdown.frame(maxWidth: .infinity, alignment: .leading)
                .frame(minWidth: 150)
            axisDropdown.frame(maxWidth: .infinity, alignment: .center)
                .frame(minWidth: 150)
            recordButton.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var sensorDropdown: some View {
        DropDownMenu(
            options: viewModel.sensorOptions,
            selectedOption: $viewModel.selectedSensor,
            onSelectionChanged: viewModel.selectSensor,
            placeholder: viewModel.sensorOptions.count > 0
                ? "Select Sensor" : "No Sensor Available"
        ).disabled(
            viewModel.sensorOptions.count == 0
                || viewModel.data.count != 0
        )
    }

    private var axisDropdown: some View {
        DropDownMenu(
            options: viewModel.axisOptions,
            selectedOption: $viewModel.selectedAxis,
            onSelectionChanged: viewModel.selectAxis,
            placeholder: viewModel.axisOptions.count == 0
                ? "-" : "Select Axis"
        ).disabled(viewModel.axisOptions.count == 0)
    }

    private var recordButton: some View {
        IconButton(
            imageSystemName: viewModel.isRecording
                ? "pause.circle" : "play.circle",
            action: viewModel.toggleRecording,
            rotation: 0,
            iconColor: viewModel.selectedSensor == nil
                ? Color(.gray) : Color(.white),
            backgroundColor: Color(.white).opacity(0)
        ).disabled(viewModel.selectedSensor == nil)
    }
}

struct MetricView: View {
    var metricName: String
    var metricValue: Double?

    var body: some View {
        VStack {
            Text(metricName).foregroundColor(Color(.white))
                .fontWeight(.bold)
            Text(
                metricValue != nil ? String(format: "%.1f", metricValue!) : "-"
            )
        }
    }
}

struct DropDownOption<T>: Identifiable {
    var id = UUID()
    var name: String
    var object: T
}

struct DropDownMenu<T>: View {
    var options: [DropDownOption<T>]
    @Binding var selectedOption: DropDownOption<T>?
    let onSelectionChanged: (DropDownOption<T>) -> Void
    var placeholder: String

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.name, action: { onSelectionChanged(option) })
            }
        } label: {
            Label(
                selectedOption?.name ?? placeholder,
                systemImage: "chevron.down"
            )
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(32)
        }
    }
}

class TimeAxisValueFormatter {
    static private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func stringForValue(baseTime: Double, _ value: Double) -> String {
        let date = Date(
            timeIntervalSinceReferenceDate: (value + baseTime) / 100.0
        )
        return formatter.string(from: date)
    }
}
