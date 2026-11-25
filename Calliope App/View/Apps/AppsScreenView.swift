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
    case appDetail(url: String, title: String, bridge: WebAppBridge)
    case info(url: String)
    case sensordata
    case sensordataRoute(ProjectAndSensorsRoute)
}

struct AppsScreenView: View {
    @ObservedObject var viewModel: AppsScreenViewModel
    @ObservedObject var sensordataViewModel: SensordataViewModel
    @StateObject private var router = Router<AppsScreenRoute>()

    var body: some View {
        RouterNavigationStack(router: router) {
            TilePageLayout(
                leftItem: viewModel.infoItem,
                data: viewModel.tileData,
                leftItemOnTap: { app in router.push(route(for: app)) },
                rightItemsOnTap: { app in router.push(route(for: app)) }
            )
        } destination: { route in
            switchRoutes(route: route)
        }
        .modifier(AlertModifier(alert: viewModel.alertBinding))
    }

    func route(for app: AppItem) -> AppsScreenRoute {
        switch app.destination {
        case .website(let url):
            return .info(url: url)
        case .webApp(let url, let bridge):
            return .appDetail(url: url, title: app.tileItem.title, bridge: bridge)
        case .sensordata:
            return .sensordata
        }
    }

    @ViewBuilder
    func switchRoutes(route: AppsScreenRoute) -> some View {
        switch route {
        case .appDetail(let url, let title, let bridge):
            AppsDetailView(url: url, title: title, bridge: bridge, alertPublisher: viewModel)
        case .info(let url):
            WebView(url: URL(string: url))
                .subpageTitle(Text("Apps Info"))
        case .sensordata:
            SensordataView(viewModel: sensordataViewModel, navigator: AppsSensordataNavigator(router: router))
                .subpageTitle(Text("Data Logger & Sensors"))
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
    let bridge: WebAppBridge
    let alertPublisher: Alertable
    @Environment(\.deviceConnection) private var connection
    @Environment(\.connectionPanel) private var connectionPanel

    var body: some View {
        RepresentableWBWebView(url: URL(string: url)!, bridge: bridge, alertPublisher: alertPublisher, connection: connection, connectionPanel: connectionPanel)
            .background(DisableSwipeBackGestureView())
            .subpageTitle(Text(verbatim: title))
    }
}

struct AppItem: HasTileItem, Hashable {
    let tileItem: TileItem
    let destination: AppDestination
}

enum AppDestination: Hashable {
    case website(url: String)
    case webApp(url: String, bridge: WebAppBridge)
    case sensordata
}

enum WebAppBridge: Hashable {
    case none
    case webBluetooth
    case native
}
