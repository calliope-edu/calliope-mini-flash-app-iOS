//
//  SensordataView.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct SensordataView: View {
    @ObservedObject var viewModel: SensordataViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 500))]) {
                sendDataTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true)
                dataLoggerTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true)
            }.frame(maxWidth: .infinity)
            projectsTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true)
                .frame(maxWidth: .infinity)
        }.padding()
    }

    var sendDataTile: some View {
        VStack(alignment: .leading) {
            Text("Send sensor data directly from Calliope mini to the app").fontWeight(.bold)
            Text("1. Open MakeCode Editor")
            Text("2. Add the Bluetooth extension to your project")
            imageButton(imageName: "calliope_bluetooth_extension 1", action: {})
            Text("3. Select the disired services for your program to view or record")
            Text("4. Start the program on your Calliope mini")
            Text("Detailed instructions can be found on the website:").fontWeight(.bold)
            boxButton(label: "calliope.cc", action: {})
        }
    }

    var dataLoggerTile: some View {
        VStack(alignment: .leading) {
            Text(
                "Data can be recorded on the Calliope mini 3. With the datalogger extension data can be saved in a table and also displayed as a graph."
            ).fontWeight(.bold)
            Text("1. This template can be used with the extension:")
            imageButton(imageName: "calliope_datalogger_extension", action: {})
            Text("2. Create the program with the respective dat aand define the required columns and se tthe corresponding (sensor) data as values.")
            Text("3. Transfer the program to your Calliope mini")
            Text("4. Open the datalogger view")
            boxButton(label: "DataLogger View", action: {})
        }
    }

    func imageButton(imageName: String, action: @escaping () -> Void) -> some View {
        return HStack {
            Spacer()
            Button(action: action) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
            }
            Spacer()
        }
    }

    func boxButton(label: String, action: @escaping () -> Void) -> some View {
        return Button {
            action()
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.calliopePink)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    var projectsTile: some View {
        VStack {
            Text(
                "Here you will find your projects. You can view, process and share the recorded data, as well as download it as a table."
            ).fontWeight(.bold)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))]) {
                ForEach(viewModel.projects) { project in
                    ProjectItem(project: project)
                }
            }

            IconButton(imageSystemName: "plus", action: {}, rotation: 0, iconColor: Color(.white), backgroundColor: Color.calliopeGreen)

        }
    }
}

extension View {
    func tiled(color: Color, cornerRadius: CGFloat = 12, takeRemainingSpace: Bool = false) -> some View {
        self.frame(maxWidth: takeRemainingSpace ? .infinity : nil)
            .frame(maxHeight: .infinity)
            .padding()
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct ProjectItem: View {
    let project: Project

    var body: some View {
        HStack {
            Text(project.name)
                .foregroundColor(Color(.white))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            Button("", systemImage: "trash", action: {}).foregroundColor(Color(.white))
        }.tiled(color: Color.calliopeDarkgray)
    }
}

struct SensordataView_Previews: PreviewProvider {
    static var previews: some View {
        let sensorDataViewModel = PreviewSensordataViewModel()
        SensordataView(viewModel: sensorDataViewModel).previewInterfaceOrientation(.portrait)
        SensordataView(viewModel: sensorDataViewModel).previewInterfaceOrientation(.landscapeLeft)
    }
}
