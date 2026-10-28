//
//  RootTabView.swift
//  Calliope App
//
//  Created by Calliope on 14.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator = RootCoordinator()
    @StateObject private var homeViewModel = HomeScreenViewModel()
    @StateObject private var uploadViewModel: UploadViewModel
    @StateObject private var editorsViewModel: EditorsAndProgramsViewModel
    @StateObject private var sensordataViewModel: SensordataViewModel
    @StateObject private var appsViewModel = AppsScreenViewModel()
    @StateObject private var rootAlertPublisher = RootAlertPublisher()
    @ObservedObject private var matrixConnectionViewModel: MatrixConnectionViewModel
    @ObservedObject private var usbDestinationPicker: USBDestinationPickerViewModel
    @State private var wasInBackground = false
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _matrixConnectionViewModel = ObservedObject(wrappedValue: dependencies.connectionPanel)
        _usbDestinationPicker = ObservedObject(wrappedValue: dependencies.usbDestinationPicker)
        let uploadViewModel = UploadViewModel(
            flashService: dependencies.flashService,
            connection: dependencies.connection,
            connectionPanel: dependencies.connectionPanel,
            usbPolicy: dependencies.usbPolicy
        )
        _uploadViewModel = StateObject(wrappedValue: uploadViewModel)
        _editorsViewModel = StateObject(wrappedValue: EditorsAndProgramsViewModel(uploadViewModel: uploadViewModel))
        _sensordataViewModel = StateObject(wrappedValue: SensordataViewModel(connection: dependencies.connection))
    }

    var body: some View {
        ZStack {
            TabView(selection: $coordinator.selectedTab) {
                HomeScreenView(viewModel: homeViewModel)
                    .tabItem { Label("Home", image: "IconDevice") }
                    .tag(0)
                EditorsAndProgramsView(viewModel: editorsViewModel)
                    .environmentObject(coordinator)
                    .tabItem { Label("Editors and Programs", image: "IconCode") }
                    .tag(1)
                SensordataView(viewModel: sensordataViewModel)
                    .tabItem { Label("Sensordaten", systemImage: "menubar.rectangle") }
                    .tag(2)
                AppsScreenView(viewModel: appsViewModel)
                    .tabItem {
                        Label {
                            Text("Apps")
                        } icon: {
                            Image(uiImage: UIImage(systemName: "square.grid.3x3") ?? UIImage())
                        }
                    }
                    .tag(3)
                if DiagnosticsFeature.isEnabled {
                    DiagnosticsView(viewModel: DiagnosticsViewModel(
                        diagnostics: DeviceDiagnostics(usbPolicy: dependencies.usbPolicy),
                        storageDiagnostics: StorageDiagnostics(storage: dependencies.documentStorage)
                    ))
                        .tabItem { Label("Diagnostics", systemImage: "stethoscope") }
                        .tag(4)
                }
            }
            .tint(Color("calliope-lilablau"))
            
            MatrixConnectionView(viewModel: matrixConnectionViewModel)
                .offset(x: -8, y: 8)
        }
        .modifier(AlertModifier(alert: matrixConnectionViewModel.alertBinding))
        .modifier(AlertModifier(alert: rootAlertPublisher.alertBinding))
        .modifier(AlertModifier(alert: uploadViewModel.alertBinding))
        .sheet(isPresented: $uploadViewModel.isSharingLog) {
            ActivityView(items: [LogNotify.recentLog])
        }
        .environmentObject(uploadViewModel)
        .environment(\.deviceConnection, dependencies.connection)
        .environment(\.documentStorage, dependencies.documentStorage)
        .environment(\.connectionPanel, dependencies.connectionPanel)
        .fileExporter(
            isPresented: usbDestinationPicker.isPresentedBinding,
            document: EmptyHexDocument(),
            contentType: EmptyHexDocument.hexType,
            defaultFilename: usbDestinationPicker.request?.filename
        ) { result in
            usbDestinationPicker.complete(result)
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
        .onAppear {
            applyCompactSizeClassOverride()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                dependencies.connection.enterBackground()
                wasInBackground = true
            case .active:
                if wasInBackground {
                    HexFileManager.startWatchingForExternalChanges()
                    NotificationCenter.default.post(name: NotificationConstants.hexFileChanged, object: nil)
                    
                    dependencies.connection.enterForeground()
                    wasInBackground = false
                }
                applyCompactSizeClassOverride()
            default:
                break
            }
        }
    }

    // Handles external opens: .hex files (Files app, Mail) and universal links
    // (makecode.calliope.cc). Replaces the old AppDelegate.application(_:open:)
    // and application(_:continue:), which are not delivered to SwiftUI apps —
    // SwiftUI passes universal links to onOpenURL as URLs.
    private func handleOpenURL(_ url: URL) {
        if url.isFileURL, FileExtension(rawValue: url.pathExtension.lowercased()) == .hex {
            LogNotify.log("received \(url.lastPathComponent)")
            HexFileStoreDialog.showStoreHexUI(
                alertPublisher: rootAlertPublisher,
                uploadViewModel: uploadViewModel,
                hexFile: url,
                notSaved: { _ in
                    //TODO: handle error
                }
            )
            return
        }

        if url.scheme == "http" || url.scheme == "https" {
            LogNotify.log("Received universal link: \(url.absoluteString)")
            openMakeCode(url: url)
        }
    }

    // Routes a universal link (e.g. https://makecode.calliope.cc/...) to the
    // MakeCode editor. In DEBUG, development domains (e.g. ngrok) are redirected
    // to the production host, matching the old AppDelegate behavior.
    private func openMakeCode(url: URL) {
        var url = url
        #if DEBUG
        if url.host != "makecode.calliope.cc" {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "makecode.calliope.cc"
            components.path = url.path
            components.query = url.query
            components.fragment = url.fragment
            let originalUrl = url.absoluteString
            if let redirectedUrl = components.url {
                url = redirectedUrl
                LogNotify.log("Redirected development domain (\(originalUrl)) to makecode (\(url.absoluteString))")
            }
        }
        #endif

        coordinator.navigateToEditor(.makeCodeLink(url: url.absoluteString))
    }

    // Replaces the old MainContainerViewController.updateTraitOverrides():
    // display the original iPhone design on iPad by forcing the compact size class.
    private func applyCompactSizeClassOverride() {
        guard #available(iOS 18.0, *) else {
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first,
            let rootViewController = window.rootViewController
        else {
            return
        }
        rootViewController.traitOverrides.horizontalSizeClass = .compact
    }
}

/// Alert publisher for flows triggered outside any single tab (e.g. a .hex file
/// opened via onOpenURL), so their dialogs present at the root over any tab.
final class RootAlertPublisher: ObservableObject, Alertable {
    @Published var alert: AppAlert? = nil

    var alertBinding: Binding<AppAlert?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }
}

// The app writes the hex content itself after the export, see USBCalliope.uploadViaExportPicker.
private struct EmptyHexDocument: FileDocument {
    static let hexType = UTType(filenameExtension: "hex") ?? .data
    static var readableContentTypes: [UTType] { [hexType] }

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}
