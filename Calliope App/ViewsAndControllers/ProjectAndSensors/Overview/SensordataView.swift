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
    @Environment(\.openURL) var openURL

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
            imageButton(imageName: "calliope_bluetooth_extension 1", action: { viewModel.openBluetoothSensorInfoWebView() })
            Text("3. Select the disired services for your program to view or record")
            Text("4. Start the program on your Calliope mini")
            Text("Detailed instructions can be found on the website:").fontWeight(.bold)
            boxButton(label: "calliope.cc", action: {viewModel.openBluetoothExtensionPage(openURL: openURL)}, enabled: true)
        }
    }

    var dataLoggerTile: some View {
        VStack(alignment: .leading) {
            Text(
                "Data can be recorded on the Calliope mini 3. With the datalogger extension data can be saved in a table and also displayed as a graph."
            ).fontWeight(.bold)
            Text("1. This template can be used with the extension:")
            imageButton(imageName: "calliope_datalogger_extension", action: {viewModel.openDataLoggerInfoWebView()})
            Text("2. Create the program with the respective data and define the required columns and se tthe corresponding (sensor) data as values.")
            Text("3. Transfer the program to your Calliope mini")
            Text("4. Open the datalogger view")
            boxButton(label: "DataLogger View", action: { viewModel.openDataLogger() }, enabled: viewModel.dataLoggerButtonEnabled)
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

    func boxButton(label: String, action: @escaping () -> Void, enabled: Bool) -> some View {
        return Button {
            action()
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
                .padding()
                .background(enabled ? Color.calliopePink : Color.calliopeGray)
                .foregroundColor(.white)
                .cornerRadius(12)
        }.disabled(!enabled)
    }

    var projectsTile: some View {
        VStack {
            Text(
                "Here you will find your projects. You can view, process and share the recorded data, as well as download it as a table."
            ).fontWeight(.bold)

            FlowLayout(spacing: 12) {
                ForEach(viewModel.projects) { project in
                    ProjectItem(project: project, viewModel: viewModel)
                }
            }

            IconButton(imageSystemName: "plus", action: {viewModel.createNewProject()}, rotation: 0, iconColor: Color(.white), backgroundColor: Color.calliopeGreen)

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
    let viewModel: SensordataViewModel

    var body: some View {
        HStack {
            Text(project.name)
                .foregroundColor(Color(.white))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            Button("", systemImage: "trash", action: { viewModel.deleteProject(id: project.id! )}).foregroundColor(Color(.white))
        }
        .tiled(color: Color.calliopeDarkgray)
        .onTapGesture {
            viewModel.openProject(project: project)
        }
    }
}

struct SensordataView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel3Projects = PreviewSensordataViewModel(projects: [
            Project(id: 1, name: "Test 1"), Project(id: 2, name: "Test 2"), Project(id: 3, name: "This is a long test name"),
        ])
        SensordataView(viewModel: viewModel3Projects).previewInterfaceOrientation(.portrait)
        SensordataView(viewModel: viewModel3Projects).previewInterfaceOrientation(.landscapeLeft)
        let viewModelManyProjects = PreviewSensordataViewModel(projects: [
            Project(id: 1, name: "Test 1"), Project(id: 2, name: "Test 2"), Project(id: 1, name: "Test 3"), Project(id: 2, name: "Test 4"),
            Project(id: 1, name: "Test 5"), Project(id: 2, name: "Test 6"), Project(id: 1, name: "Test 7"), Project(id: 2, name: "Test 8"),
        ])
        SensordataView(viewModel: viewModelManyProjects).previewInterfaceOrientation(.portrait)
        SensordataView(viewModel: viewModelManyProjects).previewInterfaceOrientation(.landscapeLeft)

    }
}
