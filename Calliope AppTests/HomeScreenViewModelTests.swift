//
//  HomeScreenViewModelTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import SwiftUI
import XCTest
@testable import Calliope_App

@MainActor
final class HomeScreenViewModelTests: XCTestCase {

    private var newsService: FakeNewsService!

    override func setUp() {
        super.setUp()
        newsService = FakeNewsService()
    }

    // MARK: - Tests

    func testFirstOnlineItemIsShownOnTheLeftAndTheRestOnTheRight() async {
        newsService.result = .success([makeNewsItem("first"), makeNewsItem("second"), makeNewsItem("third")])

        let viewModel = await makeLoadedViewModel()

        XCTAssertEqual(viewModel.leftItem?.url, "https://example.com/first")
        XCTAssertEqual(viewModel.tileData.rightItems.map(\.url), ["https://example.com/second", "https://example.com/third"])
    }

    func testEmptyOnlineNewsShowsTheGettingStartedTileOnTheLeft() async {
        newsService.result = .success([])

        let viewModel = await makeLoadedViewModel()

        XCTAssertEqual(viewModel.leftItem?.tileItem.title, NSLocalizedString("GETTING STARTED", comment: ""))
        XCTAssertEqual(viewModel.tileData.rightItems.count, 0)
    }

    func testFailedRequestShowsTheGettingStartedTileAndTheDefaultNews() async {
        newsService.result = .failure("offline")

        let viewModel = await makeLoadedViewModel()

        XCTAssertEqual(viewModel.leftItem?.tileItem.title, NSLocalizedString("GETTING STARTED", comment: ""))
        XCTAssertEqual(viewModel.tileData.rightItems.map(\.url), NewsManager.getDefaultNews().map(\.url))
    }

    // MARK: - Helpers

    // The view model starts loading in init; leftItem is set once loading has finished.
    private func makeLoadedViewModel() async -> HomeScreenViewModel {
        let viewModel = HomeScreenViewModel(newsService: newsService)
        let loaded = expectation(description: "news loaded")
        let subscription = viewModel.$leftItem.compactMap { $0 }.first().sink { _ in loaded.fulfill() }
        await fulfillment(of: [loaded], timeout: 1)
        subscription.cancel()
        return viewModel
    }

    private func makeNewsItem(_ name: String) -> NewsItem {
        NewsItem(
            tileItem: TileItem(title: name, imageSource: .local(name), color: .white, textColor: .black),
            url: "https://example.com/\(name)"
        )
    }
}
