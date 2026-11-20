//
//  NewsService.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol NewsService {
    func fetchNews() async throws -> [NewsItem]
}
