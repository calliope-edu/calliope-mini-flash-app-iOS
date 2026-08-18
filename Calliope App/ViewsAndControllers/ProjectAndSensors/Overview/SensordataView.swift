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
}

struct SensordataView<ViewModelType: SensorDataViewModelProtocol & ObservableObject & Alertable>: View {
    @ObservedObject var viewModel: ViewModelType
    @StateObject private var router = Router<ProjectAndSensorsRoute>()
    @Environment(\.openURL) var openURL
    @State private var isImportingDataLoggerFile = false

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 500))]) {
                    sendDataTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                    dataLoggerTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                }.frame(maxWidth: .infinity)
                projectsTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                    .frame(maxWidth: .infinity)
            }.padding()
                .navigationDestination(for: ProjectAndSensorsRoute.self) { route in
                    switch route {
                    case .project(let id):
                        ProjectDetailView(projectID: id, onDelete: { router.pop() })
                    case .dataLogger(let url):
                        DataLoggerDetailView(url: url)
                    case .infoWebView(let url):
                        changeMakeCodeURL(url: url.absoluteString)
                    }
                }
                .modifier(AlertModifier(alert: viewModel.alertBinding))
                .fileImporter(
                    isPresented: $isImportingDataLoggerFile,
                    allowedContentTypes: [UTType(filenameExtension: "htm")!]
                ) { result in
                    if case .success(let url) = result {
                        pushDataLogger(url: url)
                    }
                }
        }
    }

    var sendDataTile: some View {
        VStack(alignment: .leading) {
            Text("Send sensor data directly from Calliope mini to the app").fontWeight(.bold)
            Text("1. Open MakeCode Editor")
            Text("2. Add the Bluetooth extension to your project")
            imageButton(
                imageName: "calliope_bluetooth_extension 1",
                action: { router.push(.infoWebView(url: URL(string: "https://makecode.calliope.cc/#pub:_30A13o6dM9L2")!)) }
            )
            Text("3. Select the desired services for your program to view or record")
            Text("4. Start the program on your Calliope mini")
            Text("Detailed instructions can be found on the website:").fontWeight(.bold)
            boxButton(label: "calliope.cc", action: { viewModel.openBluetoothExtensionPage(openURL: openURL) }, enabled: true)
        }.frame(maxHeight: .infinity, alignment: .top)
    }

    var dataLoggerTile: some View {
        VStack(alignment: .leading) {
            Text(
                "Data can be recorded on the Calliope mini 3. With the datalogger extension data can be saved in a table and also displayed as a graph."
            ).fontWeight(.bold)
            Text("1. This template can be used with the extension:")
            imageButton(
                imageName: "calliope_datalogger_extension",
                action: { router.push(.infoWebView(url: URL(string: "https://makecode.calliope.cc/#pub:_Dv9J1xCp6HRy")!)) }
            )
            Text("2. Create the program with the respective data and define the required columns and se tthe corresponding (sensor) data as values.")
            Text("3. Transfer the program to your Calliope mini")
            Text("4. Open the datalogger view")
            boxButton(label: "DataLogger View", action: { openDataLogger() }, enabled: viewModel.dataLoggerButtonEnabled)
        }.frame(maxHeight: .infinity, alignment: .top)
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

    func changeMakeCodeURL(url: String) -> PopupEditorWebView {
        let makeCode = MakeCode()
        makeCode.url = URL(string: url)
        return PopupEditorWebView(editor: makeCode, alertPublisher: viewModel)
    }

    private func openDataLogger() {
        if viewModel.isUsbMode {
            isImportingDataLoggerFile = true
            return
        }
        guard let calliope = MatrixConnectionViewModel.instance.usageReadyCalliope as? CalliopeAPI else {
            return
        }
        downloadDataLogger(bleCalliope: calliope)
    }

    private func downloadDataLogger(bleCalliope calliope: CalliopeAPI) {
        UploadProgressViewModel.instance.startUpload()
        UploadProgressViewModel.instance.cancelAction = { calliope.cancelUtilityJob() }
        calliope.startUtilityJob(
            for: .LOG_HTML,
            onProgress: { progress in
                DispatchQueue.main.async {
                    UploadProgressViewModel.instance.updateProgress(Double(progress) / 100.0)
                }
            },
            onCompletion: {
                DispatchQueue.main.async {
                    guard let result = calliope.currentJob?.result else {
                        UploadProgressViewModel.instance.finishUpload()
                        return
                    }
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("datalogger_\(Int(Date().timeIntervalSince1970)).htm")
                    do {
                        try result.write(to: tempURL)
                        UploadProgressViewModel.instance.finishUpload()
                        router.push(.dataLogger(url: tempURL))
                    } catch {
                        LogNotify.log("Failed to store datalogger data: \(error)")
                        UploadProgressViewModel.instance.finishUpload()
                    }
                }
            },
            onFailure: {
                DispatchQueue.main.async {
                    UploadProgressViewModel.instance.finishUpload()
                    if calliope.currentJob?.jobState == .Canceled {
                        return
                    }
                    viewModel.alert = GenericAlert(
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
            router.push(.dataLogger(url: tempURL))
        } catch {
            LogNotify.log("Failed to read datalogger file: \(error)")
        }
    }

    func boxButton(label: String, action: @escaping () -> Void, enabled: Bool) -> some View {
        return Button {
            action()
        } label: {
            Text(LocalizedStringKey(label))
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
                    ProjectItem(project: project, viewModel: viewModel) {
                        router.push(.project(id: project.id!))
                    }
                }
            }.padding(.vertical, 12)

            IconButton(
                imageSystemName: "plus",
                action: {
                    viewModel.alert = NewProjectNameAlert { name in
                        if let project = Project.insertProject(name: name), let id = project.id {
                            router.push(.project(id: id))
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
                .frame(width: 150, alignment: .leading)
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
                Project(id: 1, name: "Test 1"), Project(id: 2, name: "Test 2"), Project(id: 3, name: "This is a long test name"),
            ],
            dataLoggerButtonEnabled: true
        )
        SensordataView(viewModel: viewModel3Projects).previewInterfaceOrientation(.portrait)
        SensordataView(viewModel: viewModel3Projects).previewInterfaceOrientation(.landscapeLeft)
        let viewModelManyProjects = PreviewSensordataViewModel(
            projects: [
                Project(id: 1, name: "Test 1"), Project(id: 2, name: "Test 2"), Project(id: 1, name: "Test 3"), Project(id: 2, name: "Test 4"),
                Project(id: 1, name: "Test 5"), Project(id: 2, name: "Test 6"), Project(id: 1, name: "Test 7"), Project(id: 2, name: "Test 8"),
            ],
            dataLoggerButtonEnabled: false
        )
        SensordataView(viewModel: viewModelManyProjects).previewInterfaceOrientation(.portrait)
        SensordataView(viewModel: viewModelManyProjects).previewInterfaceOrientation(.landscapeLeft)

    }
}
