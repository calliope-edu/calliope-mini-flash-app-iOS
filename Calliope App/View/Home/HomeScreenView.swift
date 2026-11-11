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

@MainActor
class HomeScreenViewModel: ObservableObject {
    @Published var leftItem: NewsItem? = nil
    private var offlineLeftItem = NewsItem(
        tileItem: TileItem(
            title: NSLocalizedString("GETTING STARTED", comment: ""),
            imageSource: ImageSource.local("teaser_onboarding"),
            color: Color("calliope-pink"),
            textColor: .white
        ),
        url: "https://calliope.cc/programmieren/mobil/ipad"
    )
    private var loadedOnlineContent = false
    private var appsPage: TilePageLayout<NewsItem>? = nil
    @Published var tileData: TileData<NewsItem> = TileData(rightItems: [])
    private let newsService: NewsService

    init(newsService: NewsService) {
        self.newsService = newsService
        if !loadedOnlineContent {
            loadNews()
        }
    }

    func loadNews() {
        guard !loadedOnlineContent else { return }
        Task {
            let newsItems: [NewsItem]
            do {
                newsItems = try await newsService.fetchNews()
                loadedOnlineContent = true
            } catch {
                newsItems = NewsManager.getDefaultNews()
                loadedOnlineContent = false
            }
            // agreed with calliope that the first item in the news.json is shown on the left side
            if loadedOnlineContent, let first = newsItems.first {
                leftItem = first
                tileData.rightItems = Array(newsItems.dropFirst())
            } else {
                leftItem = offlineLeftItem
                tileData.rightItems = newsItems
            }
        }
    }
}

struct NewsItem: HasTileItem {
    let tileItem: TileItem
    let url: String

}
