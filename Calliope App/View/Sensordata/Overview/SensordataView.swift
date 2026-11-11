//
//  SensordataView.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ProjectAndSensorsRoute: Hashable {
    case project(id: Int64)
    case dataLogger(url: URL)
    case infoWebView(url: URL)
    case dataLoggerInfo
    case projectsInfo
}

struct SensordataView<ViewModelType: SensorDataViewModelProtocol & ObservableObject & Alertable>: View {
    @ObservedObject var viewModel: ViewModelType
    let navigator: any SensordataNavigator
    @State private var isImportingDataLoggerFile = false
    @EnvironmentObject private var uploadViewModel: UploadViewModel
    @Environment(\.deviceConnection) private var connection

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 500))]) {
                sendDataTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                dataLoggerTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
            }.frame(maxWidth: .infinity)
        }.padding()
            .fileImporter(
                isPresented: $isImportingDataLoggerFile,
                allowedContentTypes: [UTType(filenameExtension: "htm")!]
            ) { result in
                if case .success(let url) = result {
                    pushDataLogger(url: url)
                }
            }
            .modifier(AlertModifier(alert: viewModel.alertBinding))
    }

    var sendDataTile: some View {
        VStack(alignment: .leading) {
            tileHeader(
                title: "PROJECTS",
                description: "Send sensor data live from your Calliope mini to the app via Bluetooth.",
                imageName: "calliope_bluetooth_extension 1",
                onInstructions: { navigator.push(.projectsInfo) }
            )
            SizedBox(height: 12)
            pillButton(label: "New Project", systemImage: "plus") {
                viewModel.alert = .newProjectName { name in
                    if let project = Project.insertProject(name: name), let id = project.id {
                        navigator.push(.project(id: id))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if !viewModel.projects.isEmpty {
                SizedBox(height: 24)
            }

            VStack {
                ForEach(viewModel.projects) { project in
                    ProjectItem(project: project, viewModel: viewModel) {
                        navigator.push(.project(id: project.id!))
                    }
                }
            }
        }.frame(maxHeight: .infinity, alignment: .top)
    }

    var dataLoggerTile: some View {
        VStack(alignment: .leading) {
            tileHeader(
                title: "DATALOGGER",
                description: "With the datalogger extension the Calliope mini 3 can record data. Afterwards you can transfer it to the app and view it in a table.",
                imageName: "calliope_datalogger_extension",
                onInstructions: { navigator.push(.dataLoggerInfo) }
            )
//            Button {
//                navigator.push(.dataLoggerInfo)
//            } label: {
//                HStack {
//                    Image(systemName: "info.circle")
//                    Text("Instructions")
//                }
//                .font(.subheadline)
//                .foregroundColor(Color.calliopePink)
//            }
            //            Text(
            //                "Data can be recorded on the Calliope mini 3. With the datalogger extension data can be saved in a table and also displayed as a graph."
            //            ).fontWeight(.bold)
            //            Text("1. This template can be used with the extension:")
            //            imageButton(
            //                imageName: "calliope_datalogger_extension",
            //                action: { navigator.push(.infoWebView(url: URL(string: "https://makecode.calliope.cc/#pub:_Dv9J1xCp6HRy")!)) }
            //            )
            //            Text("2. Create the program with the respective data and define the required columns and se tthe corresponding (sensor) data as values.")
            //            Text("3. Transfer the program to your Calliope mini")
            //            Text("4. Open the datalogger view")

            SizedBox(height: 12)
            HStack(spacing: 36) {
                pillButton(label: "Import Data") { openDataLogger() }
                pillButton(label: "Show Data", enabled: viewModel.dataLoggerButtonEnabled) { openDataLogger() }
            }
            .frame(maxWidth: .infinity)
        }.frame(maxHeight: .infinity, alignment: .top)
    }

    func tileHeader(title: LocalizedStringKey, description: LocalizedStringKey, imageName: String, onInstructions: @escaping () -> Void) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
            Text(description)
                .fixedSize(horizontal: false, vertical: true)
            SizedBox(height: 12)
            Button(action: onInstructions) {
                Text("Instructions")
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .foregroundColor(.black)
                    .overlay(Capsule().stroke(Color.black, lineWidth: 2))
            }
            .frame(maxWidth: .infinity)
            SizedBox(height: 12)
            Image(imageName)
                .resizable().scaledToFit().frame(height: 200)
                .frame(maxWidth: .infinity)
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

    private func openDataLogger() {
        if viewModel.isUsbMode {
            isImportingDataLoggerFile = true
            return
        }
        guard let calliope = connection.currentCalliope as? CalliopeAPI else {
            return
        }
        downloadDataLogger(bleCalliope: calliope)
    }

    private func downloadDataLogger(bleCalliope calliope: CalliopeAPI) {
        uploadViewModel.startProgress(cancel: { calliope.cancelUtilityJob() })
        calliope.startUtilityJob(
            for: .LOG_HTML,
            onProgress: { progress in
                DispatchQueue.main.async {
                    uploadViewModel.updateProgress(Double(progress) / 100.0)
                }
            },
            onCompletion: {
                DispatchQueue.main.async {
                    guard let result = calliope.currentJob?.result else {
                        uploadViewModel.finishProgress()
                        return
                    }
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("datalogger_\(Int(Date().timeIntervalSince1970)).htm")
                    do {
                        try result.write(to: tempURL)
                        uploadViewModel.finishProgress()
                        navigator.push(.dataLogger(url: tempURL))
                    } catch {
                        LogNotify.log("Failed to store datalogger data: \(error)")
                        uploadViewModel.finishProgress()
                    }
                }
            },
            onFailure: {
                DispatchQueue.main.async {
                    uploadViewModel.finishProgress()
                    if calliope.currentJob?.jobState == .Canceled {
                        return
                    }
                    viewModel.alert = AppAlert(
                        title: NSLocalizedString("Datalogger Download Failed!", comment: ""),
                        message: NSLocalizedString(
                            "There was an issue downloading the datalogger data from your Calliope mini. Please ensure you are connected to the Calliope and try again.",
                            comment: ""
                        ),
                        actions: [StandardAlertAction(NSLocalizedString("Cancel", comment: ""), role: .cancel, handler: {})]
                    )
                }
            }
        )
    }

    private func pushDataLogger(url: URL) {
        do {
            let data = try url.asData()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("datalogger_\(Int(Date().timeIntervalSince1970)).htm")
            try data.write(to: tempURL)
            navigator.push(.dataLogger(url: tempURL))
        } catch {
            LogNotify.log("Failed to read datalogger file: \(error)")
        }
    }

    func pillButton(label: LocalizedStringKey, systemImage: String? = nil, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(label)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(enabled ? Color.calliopeDarkgreen : Color.calliopeGray, in: Capsule())
            .foregroundColor(.white)
        }
        .disabled(!enabled)
    }

    var projectsTile: some View {
        VStack {
            Text(
                "Here you will find your projects. You can view, process and share the recorded data, as well as download it as a table."
            ).fontWeight(.bold)

            FlowLayout(spacing: 12) {
                ForEach(viewModel.projects) { project in
                    ProjectItem(project: project, viewModel: viewModel) {
                        navigator.push(.project(id: project.id!))
                    }
                }
            }.padding(.vertical, 12)

            IconButton(
                imageSystemName: "plus",
                action: {
                    viewModel.alert = .newProjectName { name in
                        if let project = Project.insertProject(name: name), let id = project.id {
                            navigator.push(.project(id: id))
                        }
                    }
                },
                rotation: 0,
                iconColor: Color(.white),
                backgroundColor: Color.calliopeGreen
            )

        }
    }
}

extension View {
    func tiled(color: Color, cornerRadius: CGFloat = 12, takeRemainingSpace: Bool = false, padding: CGFloat = 20) -> some View {
        self.frame(maxWidth: takeRemainingSpace ? .infinity : nil)
            .frame(maxHeight: .infinity)
            .padding(.all, padding)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct ProjectItem<ViewModelType: SensorDataViewModelProtocol & ObservableObject>: View {
    let project: Project
    let viewModel: ViewModelType
    var onOpen: () -> Void

    var body: some View {
        HStack {
            Text(project.name)
                .foregroundColor(Color(.white))
                .lineLimit(1)
            Spacer()
            Button("", systemImage: "trash", action: { viewModel.deleteProject(id: project.id!) }).foregroundColor(Color(.white))
        }
        .tiled(color: Color.calliopeDarkgray)
        .onTapGesture {
            onOpen()
        }
    }
}

struct SensordataView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel3Projects = PreviewSensordataViewModel(
            projects: [
                Project(id: 1, name: "Test 1"), Project(id: 2, name: "Test 2"),
                Project(id: 3, name: "This is a extra long test name to how this is formatted in the ui"),
            ],
            dataLoggerButtonEnabled: true
        )
        NavigationStack { SensordataView(viewModel: viewModel3Projects, navigator: Router<ProjectAndSensorsRoute>()) }.previewInterfaceOrientation(.portrait)
        NavigationStack { SensordataView(viewModel: viewModel3Projects, navigator: Router<ProjectAndSensorsRoute>()) }.previewInterfaceOrientation(.landscapeLeft)
        let viewModelManyProjects = PreviewSensordataViewModel(
            projects: [
                Project(id: 1, name: "Test 1"), Project(id: 2, name: "Test 2"), Project(id: 1, name: "Test 3"), Project(id: 2, name: "Test 4"),
                Project(id: 1, name: "Test 5"), Project(id: 2, name: "Test 6"), Project(id: 1, name: "Test 7"), Project(id: 2, name: "Test 8"),
            ],
            dataLoggerButtonEnabled: false
        )
        NavigationStack { SensordataView(viewModel: viewModelManyProjects, navigator: Router<ProjectAndSensorsRoute>()) }.previewInterfaceOrientation(.portrait)
        NavigationStack { SensordataView(viewModel: viewModelManyProjects, navigator: Router<ProjectAndSensorsRoute>()) }.previewInterfaceOrientation(.landscapeLeft)

    }
}
