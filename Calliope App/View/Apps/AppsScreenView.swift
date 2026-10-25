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
    case appDetail(app: AppItem)
    case info
}

struct AppsScreenView: View {
    @ObservedObject var viewModel: AppsScreenViewModel
    @StateObject private var router = Router<AppsScreenRoute>()

    var body: some View {
        NavigationStack(path: $router.path) {
            TilePageLayout(
                leftItem: viewModel.infoItem,
                data: viewModel.tileData,
                leftItemOnTap: { _ in router.push(.info) },
                rightItemsOnTap: { app in router.push(.appDetail(app: app)) }
            )
            .navigationDestination(for: AppsScreenRoute.self) { route in
                switchRoutes(route: route)
            }
        }
        .modifier(AlertModifier(alert: viewModel.alertBinding))
    }

    @ViewBuilder
    func switchRoutes(route: AppsScreenRoute) -> some View {
        switch route {
        case .appDetail(let app):
            AppsDetailView(app: app, alertPublisher: viewModel)
        case .info:
            WebView(url: URL(string: viewModel.infoItem.url))
                .navigationTitle("Apps Info")
        }
    }
}

struct AppsDetailView: View {
    let app: AppItem
    let alertPublisher: Alertable
    @Environment(\.deviceConnection) private var connection
    @Environment(\.connectionPanel) private var connectionPanel

    var body: some View {
        RepresentableWBWebView(url: URL(string: app.url)!, alertPublisher: alertPublisher, connection: connection, connectionPanel: connectionPanel)
            .navigationTitle(app.tileItem.title)
    }
}

struct AppItem: HasTileItem, Hashable {
    let tileItem: TileItem
    let url: String
}
