//
//  StorageDirectory.swift
//  Calliope App
//
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

final class StorageDirectory {

    static let shared = StorageDirectory()

    private static let containerIdentifier = "iCloud.cc.calliope.ios.flash"

    private var cachedDirectory: URL?
    private let lock = NSLock()

    private init() {}

    /// Call from AppDelegate at startup (on a background queue) to ensure the
    /// iCloud container is initialized and visible in the Files app.
    func initializeCloudStorage() {
        DispatchQueue.global(qos: .utility).async { [self] in
            do {
                let dir = try documentsDirectory()
                LogNotify.log("Storage initialized: \(dir.path)")
            } catch {
                LogNotify.log("Storage initialization failed: \(error)")
            }
        }
    }

    /// Returns the Documents directory for storing user files.
    /// Uses the iCloud container (visible in Files app under iCloud Drive)
    /// on both personal and shared iPads. Falls back to local Documents
    /// only when iCloud is genuinely unavailable.
    func documentsDirectory() throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedDirectory, FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        let resolved = try resolveDirectory()
        cachedDirectory = resolved
        return resolved
    }

    /// Resets the cached directory so the next access re-evaluates iCloud availability.
    func invalidateCache() {
        lock.lock()
        defer { lock.unlock() }
        cachedDirectory = nil
    }

    var iCloudAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return FileManager.default.url(forUbiquityContainerIdentifier: Self.containerIdentifier) != nil
    }

    /// Triggers download of an iCloud file that may only exist in the cloud.
    func startDownloadIfNeeded(at url: URL) {
        let fm = FileManager.default
        do {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if let status = resourceValues.ubiquitousItemDownloadingStatus,
               status != .current {
                try fm.startDownloadingUbiquitousItem(at: url)
            }
        } catch {
            // Not an iCloud file or already downloaded — nothing to do
        }
    }

    private func resolveDirectory() throws -> URL {
        let fm = FileManager.default

        if let containerURL = fm.url(forUbiquityContainerIdentifier: Self.containerIdentifier) {
            let icloudDocs = containerURL.appendingPathComponent("Documents")
            if !fm.fileExists(atPath: icloudDocs.path) {
                try fm.createDirectory(at: icloudDocs, withIntermediateDirectories: true)
            }
            return icloudDocs
        }

        LogNotify.log("iCloud container unavailable — falling back to local Documents")
        return try fm.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
}
