//
//  ProjectView.swift
//  Calliope App
//
//  Created by Calliope on 17.04.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

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
    
    var body: some View {
        VStack {
            ZStack {
                DropDownMenu(options: chartViewModel.axisOptions, selectedOption: $chartViewModel.selectedAxis, onSelectionChanged: chartViewModel.selectAxis,  placeholder: chartViewModel.axisOptions.count == 0 ? "-" : "Select Axis").disabled(chartViewModel.axisOptions.count == 0)
                HStack {
                    DropDownMenu(options: chartViewModel.sensorOptions, selectedOption: $chartViewModel.selectedSensor, onSelectionChanged: chartViewModel.selectSensor, placeholder: chartViewModel.sensorOptions.count > 0 ? "Select Sensor" : "No Sensor Available").disabled(chartViewModel.sensorOptions.count == 0)
                    Spacer()
                    IconButton(imageSystemName: "xmark.circle", action: onRemoveTapped, rotation: 0, iconColor: Color(.white), backgroundColor: Color(.white).opacity(0))
                }
            }
            HStack {
                Spacer()
                MetricView(metricName: "Minimum", metricValue: 0)
                Spacer()
                MetricView(metricName: "Average", metricValue: 0)
                Spacer()
                MetricView(metricName: "Maximum", metricValue: 0)
                Spacer()
                MetricView(metricName: "Current", metricValue: 0)
                Spacer()
            }
            MultiLineChartView(dataSets: $chartViewModel.data)
                    .frame(height: 250)
                    .padding()
            HStack {
                Spacer()
                IconButton(imageSystemName: chartViewModel.isRecording ? "pause.circle" : "play.circle", action: chartViewModel.toggleRecording, rotation: 0, iconColor: chartViewModel.selectedSensor==nil ? Color(.gray) : Color(.white), backgroundColor: Color(.white).opacity(0)).disabled(chartViewModel.selectedSensor==nil)
                Spacer()
            }
            
            // Placeholder for map
            /*Rectangle()
                 .fill(Color.gray.opacity(0.2))
                 .frame(maxWidth: .infinity)
                 .frame(height: 250)*/
        }.padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("calliope-turqoise"))
            )
            .padding(.horizontal)
    }
}

struct MetricView: View {
    var metricName: String
    var metricValue: Double
    
    var body: some View {
        VStack{
            Text(metricName).foregroundColor(Color(.white))
                .fontWeight(.bold)
            Text(String(format: "%.1f", metricValue)
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
