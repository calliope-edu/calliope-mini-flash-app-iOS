//
//  HomeScreenView.swift
//  Calliope App
//
//  Created by Calliope on 15.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct HomeScreenView: View {
    let onTileSelected: (_ tile: NewsItem) -> Void
    @ObservedObject var viewModel: HomeScreenViewModel

    var body: some View {
        TilePageLayout(
            leftItem: viewModel.gettingStartedItem,
            data: viewModel.tileData,
            leftItemOnTap: onTileSelected,
            rightItemsOnTap: onTileSelected
        ).onAppear { viewModel.loadNews() }
    }
}

class HomeScreenViewModel: ObservableObject {
    @Published var gettingStartedItem = NewsItem(
        tileItem: TileItem(
            title: "GETTING STARTED",
            imageSource: ImageSource.local("teaser_onboarding"),
            color: Color("calliope-pink"),
            textColor: .white
        ),
        url: "https://calliope.cc/programmieren/mobil/ipad"
    )
    private var newsItems: [NewsItem] = []
    private var loadedOnlineContent = false
    private var appsPage: TilePageLayout<NewsItem>? = nil
    @Published var tileData: TileData<NewsItem> = TileData(rightItems: [])

    init() {
        if !loadedOnlineContent {
            loadNews()
        }
    }

    func loadNews() {
        NewsManager.getNews { [weak self] result in
            switch result {
            case .success(let news):
                self?.newsItems = news
                self?.loadedOnlineContent = true
            case .failure(_):
                self?.newsItems = NewsManager.getDefaultNews()
                self?.loadedOnlineContent = false
            }
            DispatchQueue.main.async {
                self!.tileData.rightItems = self!.newsItems
            }
        }
    }
}

struct NewsItem: HasTileItem {
    let tileItem: TileItem
    let url: String
    
}
