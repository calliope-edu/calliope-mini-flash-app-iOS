//
//  DocumentStorage.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol DocumentStorage: AnyObject {
    func directory() throws -> URL

    @discardableResult
    func save(_ data: Data, as fileName: String, atomically: Bool) throws -> URL

    // Fails if a file with the same name already exists.
    @discardableResult
    func moveIn(_ file: URL) throws -> URL

    func fileExists(named fileName: String) throws -> Bool

    // Extensions are compared lowercased.
    func files(withExtensions extensions: Set<String>) throws -> [URL]

    // Fails if a file with the new name already exists.
    func rename(_ file: URL, to fileName: String) throws -> URL

    func delete(_ file: URL) throws

    func startDownloadIfNeeded(_ file: URL)
}
