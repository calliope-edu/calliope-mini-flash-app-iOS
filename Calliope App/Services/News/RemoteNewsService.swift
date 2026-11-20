//
//  RemoteNewsService.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

final class RemoteNewsService: NewsService {

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func fetchNews() async throws -> [NewsItem] {
        try await withCheckedThrowingContinuation { continuation in
            NewsManager.getNews(from: settings.newsUrl) { result in
                continuation.resume(with: result)
            }
        }
    }
}
