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
}
