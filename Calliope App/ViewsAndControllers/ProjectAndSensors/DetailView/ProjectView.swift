//
//  ProjectView.swift
//  Calliope App
//
//  Created by Calliope on 17.04.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import Charts
import MapKit

struct ProjectView: View {
    @ObservedObject var projectViewController: ProjectViewController
    @State var showMenu = false
    
    var body: some View {
        VStack {
            HStack {
                Text(projectViewController.project!.name)
                    .foregroundColor(.white)
                    .font(.title)
                
                Spacer()
                
                IconButton(imageSystemName: "ellipsis.circle", action: {showMenu = true}, rotation: 90, iconColor: Color(.white), backgroundColor: Color(.white).opacity(0))
                    .confirmationDialog("",
                                        isPresented: $showMenu,
                                        titleVisibility: .visible) {
                        Button("Delete", role: .destructive) { projectViewController.deleteProject() }
                        Button("Export (CSV)") { projectViewController.exportToCSVFile() }
                        Button("Rename") { projectViewController.renameProject() }
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("calliope-turqoise"))
            )
            .padding(.horizontal)
            
            ScrollView {
                VStack {
                    ForEach(projectViewController.charts) { chart in
                        ChartView(onRemoveTapped: {projectViewController.deleteChart(chart: chart)}, chartViewModel: ChartViewModel(chart: chart))
                    }
                    IconButton(imageSystemName: "plus.circle", action: {projectViewController.addNewSensor()}, rotation: 0, iconColor: Color(.white), backgroundColor: projectViewController.addChartButtonEnabled ? Color("calliope-turqoise") : Color(.gray)).disabled(!projectViewController.addChartButtonEnabled)
                }
            }
        }.frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
    }
}

struct ChartView: View {
    let onRemoveTapped: () -> Void
    @ObservedObject var chartViewModel: ChartViewModel
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.507222, longitude: -0.1275), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
    
    var body: some View {
        VStack {
            ZStack {
                DropDownMenu(options: chartViewModel.axisOptions, selectedOption: $chartViewModel.selectedAxis, onSelectionChanged: chartViewModel.selectAxis,  placeholder: chartViewModel.axisOptions.count == 0 ? "-" : "Select Axis").disabled(chartViewModel.axisOptions.count == 0)
                HStack {
                    DropDownMenu(options: chartViewModel.sensorOptions, selectedOption: $chartViewModel.selectedSensor, onSelectionChanged: chartViewModel.selectSensor, placeholder: chartViewModel.sensorOptions.count > 0 ? "Select Sensor" : "No Sensor Available").disabled(chartViewModel.sensorOptions.count == 0 || chartViewModel.data.count != 0)
                    Spacer()
                    IconButton(imageSystemName: "xmark.circle", action: onRemoveTapped, rotation: 0, iconColor: Color(.white), backgroundColor: Color(.white).opacity(0))
                }
            }
            HStack {
                Spacer()
                MetricView(metricName: "Minimum", metricValue: chartViewModel.minimumMetric)
                Spacer()
                MetricView(metricName: "Average", metricValue: chartViewModel.averageMetric)
                Spacer()
                MetricView(metricName: "Maximum", metricValue: chartViewModel.maximumMetric)
                Spacer()
                MetricView(metricName: "Current", metricValue: chartViewModel.currentMetric)
                Spacer()
            }
            
            VStack {
                if #available(iOS 16.0, *) {
                    let chartData: [ChartDataPoint] = chartViewModel.data.flatMap { series, dataPoints in
                        if(chartViewModel.selectedAxis == nil || chartViewModel.selectedAxis!.name == "all" || chartViewModel.selectedAxis!.name == series) {
                            return dataPoints.map {
                                ChartDataPoint(
                                    x: $0.x,
                                    y: $0.y,
                                    series: series
                                )
                            }
                        }
                        return []
                    }
                    
                    Charts.Chart {
                        ForEach(chartData) { dataPoint in
                            let xValue: PlottableValue = .value("Time", dataPoint.x)
                            let yValue: PlottableValue = .value(dataPoint.series, dataPoint.y)
                            let seriesValue: PlottableValue = .value("Axis", dataPoint.series)
                            
                            LineMark(
                                x: xValue,
                                y: yValue,
                                series: seriesValue
                            )
                            .foregroundStyle(by: seriesValue)
                        }
                    }.chartLegend(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks() { value in
                                AxisGridLine()
                                AxisValueLabel() {
                                    if let timestamp = value.as(Double.self) {
                                        Text(TimeAxisValueFormatter.stringForValue(baseTime: chartViewModel.baseTime ?? 0, timestamp))
                                    }
                                }
                            }
                        }
//                        .chartXAxis(.hidden)
                        .frame(minHeight: 250)
                        .background(Color.white)
                    
                } else {
                    Text("Too old iOS Version")
                }
            }
            .padding() // space between chart and container edge
            .background(Color.white)
            .cornerRadius(12)
            
            HStack {
                Spacer()
                IconButton(imageSystemName: chartViewModel.isRecording ? "pause.circle" : "play.circle", action: chartViewModel.toggleRecording, rotation: 0, iconColor: chartViewModel.selectedSensor==nil ? Color(.gray) : Color(.white), backgroundColor: Color(.white).opacity(0)).disabled(chartViewModel.selectedSensor==nil)
                Spacer()
            }
            
            ZStack {
                Map(coordinateRegion: $region,
                    annotationItems: Array(chartViewModel.uniqueLocations)
                ) { place in
                    MapAnnotation(coordinate: place.location) {
                        Circle().frame(width: 20, height: 20)
                    }
                }
                .frame(height: 300)
                .cornerRadius(12)
                
                Text("\(chartViewModel.uniqueLocations.count) unique locations").padding()
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .topTrailing)

                
                IconButton(imageSystemName: "scope", action: resetRegion, rotation: 0, iconColor: Color(.black), backgroundColor: Color(.white)).padding()
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .bottomTrailing)
            }
            
            
        }.padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("calliope-turqoise"))
            )
            .padding(.horizontal)
        
        
    }
    
    func resetRegion() {
        var center = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        if(chartViewModel.uniqueLocations.count > 0) {
            for place in chartViewModel.uniqueLocations {
                center.latitude += place.location.latitude
                center.longitude += place.location.longitude
            }
            center.latitude /= Double(chartViewModel.uniqueLocations.count)
            center.longitude /= Double(chartViewModel.uniqueLocations.count)
        }
        
        var maxDistanceFromCenter = 0.002
        let centerCL = CLLocation(latitude: center.latitude, longitude: center.longitude)
        for place in chartViewModel.uniqueLocations {
            let distance = centerCL.distance(from: CLLocation(latitude: place.location.latitude, longitude: place.location.longitude))
            if distance > maxDistanceFromCenter {
                maxDistanceFromCenter = distance
            }
        }
        
        region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: maxDistanceFromCenter, longitudeDelta: maxDistanceFromCenter))
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let series: String
}

struct MetricView: View {
    var metricName: String
    var metricValue: Double?
    
    var body: some View {
        VStack{
            Text(metricName).foregroundColor(Color(.white))
                .fontWeight(.bold)
            Text(metricValue != nil ? String(format: "%.1f", metricValue!) : "-")
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
            Label(selectedOption?.name ?? placeholder, systemImage: "chevron.down")
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(32)
        }
    }
}

struct IconButton: View {
    var imageSystemName: String
    var action: () -> Void
    var rotation: Double
    var iconColor: Color
    var backgroundColor: Color
    
    var body: some View {
        Button(action: action) {
            Image(systemName: imageSystemName)
                .font(.system(size: 32))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(rotation))
                .background(Circle().fill(backgroundColor).frame(width: 44, height: 44))
        }
    }
}

struct ProjectView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectView(projectViewController: ProjectViewController(coder: NSCoder())!)
    }
}

class TimeAxisValueFormatter {
    static private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func stringForValue(baseTime: Double, _ value: Double) -> String {
        let date = Date(timeIntervalSinceReferenceDate: (value + baseTime) / 100.0)
        return formatter.string(from: date)
    }
}
