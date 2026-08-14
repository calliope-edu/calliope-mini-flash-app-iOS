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
    @State private var wasInBackground = false

    var body: some View {
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
        .modifier(AlertModifier(alert: MatrixConnectionViewModel.instance.alertBinding))
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

    // Replaces the old MainContainerViewController.updateTraitOverrides():
    // display the original iPhone design on iPad by forcing the compact size class.
    private func applyCompactSizeClassOverride() {
        guard #available(iOS 18.0, *) else {
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        rootViewController.traitOverrides.horizontalSizeClass = .compact
    }
}
