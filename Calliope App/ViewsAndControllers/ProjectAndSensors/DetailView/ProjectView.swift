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
    @ObservedObject var projectViewController: ProjectViewModel
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
                    ForEach(projectViewController.chartViewModels) { chartViewModel in
                        ChartCellView(onRemoveTapped: {projectViewController.deleteChart(chart: chartViewModel.chart)}, chartViewModel: chartViewModel)
                    }
                    IconButton(imageSystemName: "plus.circle", action: {projectViewController.addNewSensor()}, rotation: 0, iconColor: Color(.white), backgroundColor: projectViewController.addChartButtonEnabled ? Color("calliope-turqoise") : Color(.gray)).disabled(!projectViewController.addChartButtonEnabled)
                }
            }
        }.frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
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
        ProjectView(projectViewController: ProjectViewModel(coder: NSCoder())!)
    }
}
