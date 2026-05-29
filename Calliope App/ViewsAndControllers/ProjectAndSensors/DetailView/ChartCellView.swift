//
//  ChartView.swift
//  Calliope App
//
//  Created by Calliope on 08.05.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Charts
import Foundation
import MapKit
import SwiftUI

struct ChartCellView: View {
    let onRemoveTapped: () -> Void
    @ObservedObject var chartViewModel: ChartCellViewModel

    var body: some View {
        VStack {
            ChartHeaderView(
                viewModel: chartViewModel,
                onRemoveTapped: onRemoveTapped
            )

            MetricsRowView(viewModel: chartViewModel)

            ChartView(viewModel: chartViewModel)

            HStack {
                Spacer()
                IconButton(
                    imageSystemName: chartViewModel.isRecording
                        ? "pause.circle" : "play.circle",
                    action: chartViewModel.toggleRecording,
                    rotation: 0,
                    iconColor: chartViewModel.selectedSensor == nil
                        ? Color(.gray) : Color(.white),
                    backgroundColor: Color(.white).opacity(0)
                ).disabled(chartViewModel.selectedSensor == nil)
                Spacer()
            }

            MapView(viewModel: chartViewModel)
        }.padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("calliope-turqoise"))
            )
            .padding(.horizontal)

    }
}

struct MapView: View {
    @ObservedObject var viewModel: ChartCellViewModel

    private var region: Binding<MKCoordinateRegion> {
        Binding {
            viewModel.region
        } set: { region in
            DispatchQueue.main.async {
                viewModel.region = region
            }
        }
    }

    var body: some View {
        ZStack {
            Map(
                coordinateRegion: region,
                annotationItems: Array(viewModel.uniqueLocations)
            ) { place in
                MapAnnotation(coordinate: place.location) {
                    Circle().frame(width: 20, height: 20)
                }
            }
            .frame(height: 300)
            .cornerRadius(12)

            Text("\(viewModel.uniqueLocations.count) unique locations")
                .padding()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topTrailing
                )

            IconButton(
                imageSystemName: "scope",
                action: viewModel.calculateCenterRegion,
                rotation: 0,
                iconColor: Color(.black),
                backgroundColor: Color(.white)
            ).padding()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottomTrailing
                )
        }
    }
}

struct ChartView: View {
    @ObservedObject var viewModel: ChartCellViewModel
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
    
    fileprivate func zoomGesture(_ geo: GeometryProxy) -> _EndedGesture<GestureStateGesture<MagnificationGesture, CGFloat>> {
        return MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = 1 / value
                state = max(0.001 / currentScale, min(1.5 / currentScale, state))
                calculateDisplayedRange(
                    graphWidth: geo.size.width
                )
            }
            .onEnded { value in
                currentScale /= value
                currentScale = max(0.001, min(1.5, currentScale))
                calculateDisplayedRange(
                    graphWidth: geo.size.width
                )
            }
    }
    
    fileprivate func dragGesture(_ geo: GeometryProxy) -> _EndedGesture<GestureStateGesture<DragGesture, CGSize>> {
        return DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state.width = -value.translation.width * zoom * (totalRangeWidth / geo.size.width)
                state.width = max(minimumX - currentOffset.width, min(maximumX - currentOffset.width, state.width))
                calculateDisplayedRange(
                    graphWidth: geo.size.width
                )
            }
        
            .onEnded { value in
                currentOffset.width -=
                value.translation.width * zoom * (totalRangeWidth / geo.size.width)
                currentOffset.width = max(minimumX, min(maximumX, currentOffset.width))
                calculateDisplayedRange(
                    graphWidth: geo.size.width
                )
            }
    }
    
    var body: some View {
        VStack {
            GeometryReader { geo in
                Charts.Chart {
                    ForEach(viewModel.displayedChartData) { dataPoint in
                        let xValue: PlottableValue = .value("Time", dataPoint.x)
                        let yValue: PlottableValue = .value(
                            dataPoint.series,
                            dataPoint.y
                        )
                        let seriesValue: PlottableValue = .value(
                            "Axis",
                            dataPoint.series
                        )

                        LineMark(
                            x: xValue,
                            y: yValue,
                            series: seriesValue
                        )
                        .foregroundStyle(
                            viewModel.getColorForAxis(axis: dataPoint.series)
                        )
                    }
                }.chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading)  // puts the y axis on the left side of the view
                    }
                    .chartYScale(
                        domain: (viewModel.absoluteMinimum ?? 0)...(viewModel
                            .absoluteMaximum ?? 1)
                    )
                    .chartXAxis {
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
                        currentOffset.width = totalRangeWidth / 2 // ensures that it zooms around the center in the beginning
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
}

struct MetricsRowView: View {
    @ObservedObject var viewModel: ChartCellViewModel

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
    @ObservedObject var viewModel: ChartCellViewModel
    var onRemoveTapped: () -> Void
    @State var showMenu = false

    var body: some View {
        ZStack {
            DropDownMenu(
                options: viewModel.axisOptions,
                selectedOption: $viewModel.selectedAxis,
                onSelectionChanged: viewModel.selectAxis,
                placeholder: viewModel.axisOptions.count == 0
                    ? "-" : "Select Axis"
            ).disabled(viewModel.axisOptions.count == 0)
            HStack {
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
                Spacer()
                IconButton(
                    imageSystemName: "ellipsis.circle",
                    action: { showMenu = true },
                    rotation: 90,
                    iconColor: Color(.white),
                    backgroundColor: Color(.white).opacity(0)
                )
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
