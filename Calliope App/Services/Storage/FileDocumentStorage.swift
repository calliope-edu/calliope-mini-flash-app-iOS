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

    var isICloud: Bool {
        guard let directory = try? directory() else { return false }
        return fileManager.isUbiquitousItem(at: directory)
    }

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

    func fileExists(named fileName: String) throws -> Bool {
        fileManager.fileExists(atPath: try directory().appendingPathComponent(fileName).path)
    }

    func files(withExtensions extensions: Set<String>) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directory(),
            includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey],
            options: .skipsSubdirectoryDescendants
        )
        .filter { extensions.contains($0.pathExtension.lowercased()) }
    }

    func rename(_ file: URL, to fileName: String) throws -> URL {
        let destination = file.deletingLastPathComponent().appendingPathComponent(fileName)
        try fileManager.moveItem(at: file, to: destination)
        return destination
    }

    func delete(_ file: URL) throws {
        try fileManager.removeItem(at: file)
    }

    func startDownloadIfNeeded(_ file: URL) {
        StorageDirectory.shared.startDownloadIfNeeded(at: file)
    }
}
