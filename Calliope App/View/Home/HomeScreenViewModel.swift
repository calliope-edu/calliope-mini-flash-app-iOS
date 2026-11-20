//
//  HomeScreenViewModel.swift
//  Calliope App
//
//  Created by Calliope on 11.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

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
