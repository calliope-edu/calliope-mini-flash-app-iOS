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
    let project: Project
    
    var body: some View {
        VStack {
            HStack {
                Text(project.name)
                    .foregroundColor(.white)
                    .font(.title)
                
                Spacer()
                
                IconButton(imageSystemName: "ellipsis.circle", action: {print("More tapped")}, rotation: 90, iconColor: Color(.white), backgroundColor: Color(.white).opacity(0))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("calliope-turqoise"))
            )
            .padding(.horizontal)
            
            ScrollView {
                VStack {
                    GroupView()
                }
            }
        }.frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
    }
}

struct GroupView: View {
    var body: some View {
         VStack {
            ChartView()
             Divider()
             ChartView()
             Divider()
             ChartView()
             Divider()
             
             IconButton(imageSystemName: "plus.circle", action: {print("Add tapped")}, rotation: 0, iconColor: Color(.white), backgroundColor: Color(.white).opacity(0))

             Rectangle()
                 .fill(Color.gray.opacity(0.2))
                 .frame(maxWidth: .infinity)
                 .frame(height: 250)
         }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("calliope-turqoise"))
            )
            .padding(.horizontal)

    }
}

struct ChartView: View {
    var body: some View {
        VStack {
            HStack {
                DropDownMenu(options: [DropDownOption(name: "Accelerometer"), DropDownOption(name: "Temperature")], placeholder: "Select Sensor")
                Spacer()
                DropDownMenu(options: [DropDownOption(name: "All"), DropDownOption(name: "x")], placeholder: "Select Axis")
                Spacer()
                IconButton(imageSystemName: "xmark.circle", action: {print("Close tapped")}, rotation: 0, iconColor: Color(.white), backgroundColor: Color(.white).opacity(0))
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
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            HStack {
                Spacer()
                IconButton(imageSystemName: "play.circle", action: {print("PLay tapped")}, rotation: 0, iconColor: Color(.white), backgroundColor: Color(.white).opacity(0))
                Spacer()
            }
        }
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

struct DropDownOption: Identifiable {
    var id = UUID()
    var name: String
}

struct DropDownMenu: View {
    var options: [DropDownOption]
    @State var selectedOption: DropDownOption?
    var placeholder: String
    
    var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.name, action: { selectedOption = option })
            }
        } label: {
            Label(selectedOption != nil ? selectedOption!.name : placeholder, systemImage: "chevron.down")
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
        ProjectView(project: Project(name: "Test Project"))
    }
}
