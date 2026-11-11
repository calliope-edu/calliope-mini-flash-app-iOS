//
//  HomeScreenView.swift
//  Calliope App
//
//  Created by Calliope on 15.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

enum HomeScreenRoute: Hashable {
    case offlineOnboardingView
    case newsDetailView(url: URL)
}

struct NewsItem: HasTileItem {
    let tileItem: TileItem
    let url: String

}

struct HomeScreenView: View {
    @ObservedObject var viewModel: HomeScreenViewModel
    var network: Network = Network()
    @StateObject private var router = Router<HomeScreenRoute>()

    var body: some View {
        NavigationStack(path: $router.path) {
            TilePageLayout(
                leftItem: viewModel.leftItem,
                data: viewModel.tileData,
                leftItemOnTap: onTileSelected,
                rightItemsOnTap: onTileSelected
            ).onAppear { viewModel.loadNews() }
                .navigationDestination(for: HomeScreenRoute.self) { route in
                    switch route {
                    case .newsDetailView(let url):
                        NewsDetailWebView(url: url) {
                            router.pop()
                            router.push(.offlineOnboardingView)
                        }
                    case .offlineOnboardingView:
                        OfflineOnboardingView()
                    }
                }
        }
    }
    
    func onTileSelected(tile: NewsItem) {
        if network.isNetworkAvailable() {
            let url = URL(string: tile.url)
            if url != nil {
                router.push(.newsDetailView(url: url!))
            }
        } else {
            router.push(.offlineOnboardingView)
        }
    }
}
