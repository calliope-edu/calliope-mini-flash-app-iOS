//
//  FakeNewsService.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
@testable import Calliope_App

final class FakeNewsService: NewsService {
    var result: Result<[NewsItem], Error> = .success([])

    func fetchNews() async throws -> [NewsItem] {
        try result.get()
    }
}
