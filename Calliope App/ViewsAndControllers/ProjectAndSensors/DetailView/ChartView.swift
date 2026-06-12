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
    @State private var currentScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureOffset: CGSize = .zero
    @State private var displayedRange: ClosedRange<Double>?

    var zoom: CGFloat {
        return currentScale * gestureScale
    }

    var offset: Double {
        return currentOffset.width + gestureOffset.width
    }

    var minimumX: Double {
        return viewModel.minimumX ?? 0
    }

    var maximumX: Double {
        return viewModel.maximumX ?? 1
    }

    var totalRangeWidth: Double {
        return maximumX - minimumX
    }

    var maxRange: ClosedRange<Double> {
        return (viewModel.minimumX ?? 0)...(viewModel.maximumX ?? 1)
    }

    func calculateDisplayedRange(graphWidth: Double) {
        let displayedMinimumX = offset - totalRangeWidth * zoom / 2
        let displayedMaximumX = offset + totalRangeWidth * zoom / 2
        displayedRange = displayedMinimumX...displayedMaximumX
    }

    func ensureOffset(graphWidth: Double) {
        if displayedRange!.lowerBound < minimumX {
            let shift = minimumX - displayedRange!.lowerBound
            currentOffset.width = currentOffset.width + shift
        } else if displayedRange!.upperBound > maximumX {
            let shift = displayedRange!.upperBound - maximumX
            currentOffset.width = currentOffset.width - shift
        }
        calculateDisplayedRange(graphWidth: graphWidth)
    }

    fileprivate func zoomGesture(_ geo: GeometryProxy) -> _EndedGesture<
        GestureStateGesture<MagnificationGesture, CGFloat>
    > {
        let minScale = 0.001
        let maxScale = 1.0

        return MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = 1 / value
                state = max(
                    minScale / currentScale,
                    min(maxScale / currentScale, state)
                )
                calculateDisplayedRange(
                    graphWidth: geo.size.width
                )
                ensureOffset(graphWidth: geo.size.width)
            }
            .onEnded { value in
                currentScale /= value
                currentScale = max(minScale, min(maxScale, currentScale))
                calculateDisplayedRange(
                    graphWidth: geo.size.width
                )
                ensureOffset(graphWidth: geo.size.width)
            }
    }

    fileprivate func dragGesture(_ geo: GeometryProxy) -> _EndedGesture<
        GestureStateGesture<DragGesture, CGSize>
    > {
        let displayedRangeWidth = totalRangeWidth * zoom
        let minimumOffset = minimumX + (displayedRangeWidth / 2)
        let maximumOffset = maximumX - (displayedRangeWidth / 2)
        return DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state.width =
                    -value.translation.width * zoom
                    * (totalRangeWidth / geo.size.width)
                state.width = max(
                    minimumOffset - currentOffset.width,
                    min(maximumOffset - currentOffset.width, state.width)
                )
                calculateDisplayedRange(
                    graphWidth: geo.size.width
                )
            }

            .onEnded { value in
                currentOffset.width -=
                    value.translation.width * zoom
                    * (totalRangeWidth / geo.size.width)
                currentOffset.width = max(
                    minimumOffset,
                    min(maximumOffset, currentOffset.width)
                )
                calculateDisplayedRange(
                    graphWidth: geo.size.width
                )
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
                        domain: displayedRange ?? maxRange
                    )
                    .gesture(
                        SimultaneousGesture(
                            zoomGesture(geo),
                            dragGesture(geo)
                        )
                    )
                    .onAppear {
                        currentOffset.width = totalRangeWidth / 2  // ensures that it zooms around the center in the beginning
                        calculateDisplayedRange(graphWidth: geo.size.width)
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
            locationMarker
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
    var locationMarker: some ChartContent {
        if viewModel.markerPosition != nil {
            RuleMark(
                x: .value("Time", viewModel.markerPosition!)
            )
        }
    }

    @ChartContentBuilder
    var sliderMarker: some ChartContent {
        if displayedRange != nil {
            let displayedRangeWidth = displayedRange!.upperBound - displayedRange!.lowerBound
            RuleMark(
                x: .value("Time", viewModel.sliderPosition * displayedRangeWidth + displayedRange!.lowerBound)
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
