//
//  AppsScreenView.swift
//  Calliope App
//
//  Created by Calliope on 14.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

enum AppsScreenRoute: Hashable {
    case appDetail(url: String, title: String)
    case info(url: String)
    case sensordata
    case sensordataRoute(ProjectAndSensorsRoute)
}

struct AppsScreenView: View {
    @ObservedObject var viewModel: AppsScreenViewModel
    @ObservedObject var sensordataViewModel: SensordataViewModel
    @StateObject private var router = Router<AppsScreenRoute>()

    var body: some View {
        NavigationStack(path: $router.path) {
            TilePageLayout(
                leftItem: viewModel.infoItem,
                data: viewModel.tileData,
                leftItemOnTap: { app in router.push(route(for: app)) },
                rightItemsOnTap: { app in router.push(route(for: app)) }
            )
            .navigationDestination(for: AppsScreenRoute.self) { route in
                switchRoutes(route: route)
            }
        }
        .modifier(AlertModifier(alert: viewModel.alertBinding))
    }

    func route(for app: AppItem) -> AppsScreenRoute {
        switch app.destination {
        case .website(let url):
            return .info(url: url)
        case .webApp(let url):
            return .appDetail(url: url, title: app.tileItem.title)
        case .sensordata:
            return .sensordata
        }
    }

    @ViewBuilder
    func switchRoutes(route: AppsScreenRoute) -> some View {
        switch route {
        case .appDetail(let url, let title):
            AppsDetailView(url: url, title: title, alertPublisher: viewModel)
        case .info(let url):
            WebView(url: URL(string: url))
                .navigationTitle("Apps Info")
        case .sensordata:
            SensordataView(viewModel: sensordataViewModel, navigator: AppsSensordataNavigator(router: router))
                .navigationTitle("Data Logger & Sensors")
        case .sensordataRoute(let sensordataRoute):
            SensordataRouteView(route: sensordataRoute, navigator: AppsSensordataNavigator(router: router), viewModel: sensordataViewModel)
        }
    }
}

private struct AppsSensordataNavigator: SensordataNavigator {
    let router: Router<AppsScreenRoute>

    func push(_ route: ProjectAndSensorsRoute) {
        router.push(.sensordataRoute(route))
    }

    func pop() {
        router.pop()
    }
}

struct AppsDetailView: View {
    let url: String
    let title: String
    let alertPublisher: Alertable
    @Environment(\.deviceConnection) private var connection
    @Environment(\.connectionPanel) private var connectionPanel

    var body: some View {
        RepresentableWBWebView(url: URL(string: url)!, alertPublisher: alertPublisher, connection: connection, connectionPanel: connectionPanel)
            .navigationTitle(title)
    }
}

struct AppItem: HasTileItem, Hashable {
    let tileItem: TileItem
    let destination: AppDestination
}

enum AppDestination: Hashable {
    case website(url: String)
    case webApp(url: String)
    case sensordata
}
