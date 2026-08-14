//
//  RootTabView.swift
//  Calliope App
//
//  Created by Calliope on 14.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI
import UIKit

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator = RootCoordinator()
    @StateObject private var homeViewModel = HomeScreenViewModel()
    @StateObject private var editorsViewModel = EditorsAndProgramsViewModel()
    @StateObject private var sensordataViewModel = SensordataViewModel()
    @StateObject private var lofiAppsViewModel = LofiAppsViewModel()
    @StateObject private var rootAlertPublisher = RootAlertPublisher()
    @State private var wasInBackground = false

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
                LofiAppsView(viewModel: lofiAppsViewModel)
                    .tabItem { Label("Apps", systemImage: "rectangle.grid.3x3") }
                    .tag(3)
            }
            .tint(Color("calliope-lilablau"))
            
            MatrixConnectionView(viewModel: MatrixConnectionViewModel.instance)
        }
        .modifier(AlertModifier(alert: MatrixConnectionViewModel.instance.alertBinding))
        .modifier(AlertModifier(alert: rootAlertPublisher.alertBinding))
        .onOpenURL { url in
            handleOpenURL(url)
        }
        .onAppear(perform: applyCompactSizeClassOverride)
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                MatrixConnectionViewModel.instance.moveToBackground()
                wasInBackground = true
            case .active:
                if wasInBackground {
                    MatrixConnectionViewModel.instance.moveToForeground()
                    wasInBackground = false
                }
                applyCompactSizeClassOverride()
            default:
                break
            }
        }
    }

    // Handles opening external hex files (e.g. from the Files app or Mail).
    // Replaces the old AppDelegate.application(_:open:options:), which is not
    // delivered to SwiftUI scene-based apps.
    private func handleOpenURL(_ url: URL) {
        guard url.isFileURL, FileExtension(rawValue: url.pathExtension.lowercased()) == .hex else {
            return
        }
        LogNotify.log("received \(url.lastPathComponent)")
        HexFileStoreDialogSwiftUI.showStoreHexUI(
            alertPublisher: rootAlertPublisher,
            hexFile: url,
            notSaved: { _ in
                //TODO: handle error
            }
        )
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
final class RootAlertPublisher: ObservableObject, Alertable, CanShowProgess {
    @Published var alert: (any AppAlert)? = nil

    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }

    var progress: (any ProgressAlert)?
}
