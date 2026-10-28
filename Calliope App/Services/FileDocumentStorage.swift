//
//  FileDocumentStorage.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

final class FileDocumentStorage: DocumentStorage {

    private let resolveDirectory: () throws -> URL
    private let fileManager: FileManager

    init(
        resolveDirectory: @escaping () throws -> URL = { try StorageDirectory.shared.documentsDirectory() },
        fileManager: FileManager = .default
    ) {
        self.resolveDirectory = resolveDirectory
        self.fileManager = fileManager
    }

    // MARK: - Public API

    func directory() throws -> URL {
        try resolveDirectory()
    }

    @discardableResult
    func save(_ data: Data, as fileName: String, atomically: Bool) throws -> URL {
        let destination = try directory().appendingPathComponent(fileName)
        try data.write(to: destination, options: atomically ? .atomic : [])
        return destination
    }

    @discardableResult
    func moveIn(_ file: URL) throws -> URL {
        let destination = try directory().appendingPathComponent(file.lastPathComponent)
        try fileManager.moveItem(at: file, to: destination)
        return destination
    }
}
