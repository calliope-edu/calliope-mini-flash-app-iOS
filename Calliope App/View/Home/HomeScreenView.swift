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
    case newsDetailView(url: URL, title: String)
}

struct NewsItem: HasTileItem {
    let tileItem: TileItem
    let url: String

}

struct HomeScreenView: View {
    @ObservedObject var viewModel: HomeScreenViewModel
    @StateObject private var router = Router<HomeScreenRoute>()

    var body: some View {
        RouterNavigationStack(router: router) {
            TilePageLayout(
                leftItem: viewModel.leftItem,
                data: viewModel.tileData,
                leftItemOnTap: onTileSelected,
                rightItemsOnTap: onTileSelected
            ).onAppear { viewModel.loadNews() }
        } destination: { route in
            switch route {
            case .newsDetailView(let url, let title):
                NewsDetailWebView(url: url) {
                    router.pop()
                    router.push(.offlineOnboardingView)
                }
                .navigationTitle(title)
            case .offlineOnboardingView:
                OfflineOnboardingView()
                    .navigationTitle("Offline Information")
            }
        }
    }
    
    func onTileSelected(tile: NewsItem) {
        if let url = URL(string: tile.url) {
            router.push(.newsDetailView(url: url, title: tile.tileItem.title))
        }
    }
}
