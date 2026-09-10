//
//  HexFileManager.swift
//  Calliope App
//
//  Created by itestra on 18.01.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

final class HexFileManager {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private static func dir() throws -> URL {
        try StorageDirectory.shared.documentsDirectory()
    }
    
    private static func dateFor(url:URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let date = attributes[.creationDate] as? Date else { throw "invalid date" }
        return date
    }
    
    public static func builtins() throws -> [HexFile] {
        let names = [
            "Calliope-mini-Start",
        ]
        return try names.map({ name -> HexFile in
            guard let url = Bundle.main.url(forResource: name, withExtension: "hex") else {
                throw "invalid url"
            }
            let date = try dateFor(url:url)
            return HexFile(url: url, name: name, date: date)
        })
    }
    
    public static func stored() throws -> [HexFile] {
        let dir = try self.dir()
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey],
            options: .skipsSubdirectoryDescendants)
        // Programs are not hex-only: the Python editor saves .py, the Blocks
        // editor .sb3, and editors can save images (.png). They all belong in the
        // list — only transferring is restricted to hex (see
        // `FileExtension.isFlashable`).
        let listed = Set(FileExtension.listedInPrograms.map { $0.rawValue })
        return try urls.filter({ url -> Bool in
            return listed.contains(url.pathExtension.lowercased())
        })
        .map { url -> HexFile in
            StorageDirectory.shared.startDownloadIfNeeded(at: url)
            let name = url.deletingPathExtension().lastPathComponent
            let date = try dateFor(url:url)
            return HexFile(url: url, name: name, date: date)
        }.sorted(by: { (a,b) -> Bool in
            return a.date > b.date
        })
    }
    
    /// Legacy entry point. `isHexFile: false` means "an image", and it keeps
    /// returning `nil` for it, because callers use that to decide NOT to flash
    /// what they just saved.
    public static func store(name: String, data: Data, overrideDuplicate: Bool = true, isHexFile: Bool = true) throws -> HexFile? {
        let stored = try store(name: name, data: data, fileExtension: isHexFile ? .hex : .png, overrideDuplicate: overrideDuplicate)
        return isHexFile ? stored : nil
    }

    /// Writes a program file of any listed type into the programs directory and
    /// returns it, so non-hex saves (.py, .sb3, .png) show up in the list too.
    @discardableResult
    public static func store(name: String, data: Data, fileExtension: FileExtension, overrideDuplicate: Bool = true) throws -> HexFile? {
        let dir = try self.dir()
        let file = dir.appendingPathComponent(name + "." + fileExtension.rawValue)
        LogNotify.log("writing file \(file)")
        if !overrideDuplicate && FileManager.default.fileExists(atPath: file.path) {
            throw NSLocalizedString("File already exists", comment: "")
        }
        do {
            try data.write(to: file)
            // Clear filtered hex cache when new hex file is written
            if fileExtension == .hex {
                PartialFlashManager.clearCache()
            }
        } catch {
            LogNotify.log("\(error)")
            return nil
        }
        let hexFile = HexFile(url: file, name: name, date: Date())
        notifyChange()
        return hexFile
    }
    
    public static func delete(file: HexFile) throws {
        LogNotify.log("deleting file \(file)")
        try FileManager.default.removeItem(at: file.url)
        notifyChange()
    }
    
    public static func rename(file: HexFile) throws -> URL {
        LogNotify.log("renaming file \(file)")
        // Keep the original extension — a .py must not become a .hex on rename.
        let ext = file.url.pathExtension.isEmpty ? "hex" : file.url.pathExtension
        let newURL = file.url.deletingLastPathComponent().appendingPathComponent(file.name + "." + ext)
        try FileManager.default.moveItem(at: file.url, to: newURL)
        notifyChange()
        return newURL
    }
    
    public static var bulkChange = false {
        didSet {
            if oldValue == true && bulkChange == false {
                notifyChange()
            }
        }
    }

    private static func notifyChange() {
        if !bulkChange {
            NotificationCenter.default.post(name: NotificationConstants.hexFileChanged, object: self)
        }
    }

    // MARK: - External change watcher
    //
    // Watches the storage directory (iCloud or local Documents) for files added,
    // deleted or renamed by *outside* the app — e.g. drag-and-drop from the Files
    // app, iCloud sync from another device, share-sheet imports.
    //
    // Implementation uses kqueue via DispatchSourceFileSystemObject. This is a
    // zero-cost listener: the dispatch source sleeps until the kernel signals a
    // change on the directory's file descriptor. No polling, no CPU.

    private static var dirWatcherSource: DispatchSourceFileSystemObject?
    private static var dirWatcherFD: CInt = -1
    private static let watcherQueue = DispatchQueue(label: "cc.calliope.hexFileWatcher", qos: .utility)

    /// Starts (or re-starts) the file-system watcher on the current storage
    /// directory. Safe to call multiple times; idempotent. Call once at app
    /// launch — and again if the storage directory might have changed
    /// (e.g. after iCloud became available).
    public static func startWatchingForExternalChanges() {
        watcherQueue.async {
            stopWatchingInternal()

            let dirURL: URL
            do {
                dirURL = try self.dir()
            } catch {
                LogNotify.log("HexFile watcher: could not resolve storage dir: \(error)")
                return
            }

            let fd = open(dirURL.path, O_EVTONLY)
            guard fd >= 0 else {
                LogNotify.log("HexFile watcher: open() failed for \(dirURL.path), errno=\(errno)")
                return
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename, .extend],
                queue: watcherQueue
            )

            source.setEventHandler {
                // Any change in directory contents → notify listeners.
                // The Programs list controller re-queries HexFileManager.stored().
                LogNotify.log("HexFile watcher: directory changed, posting hexFileChanged")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NotificationConstants.hexFileChanged, object: self)
                }
                // If the directory itself disappears (rare — e.g. iCloud reset),
                // restart the watcher so we pick up the new descriptor.
                let event = source.data
                if event.contains(.delete) || event.contains(.rename) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        startWatchingForExternalChanges()
                    }
                }
            }

            source.setCancelHandler {
                close(fd)
            }

            dirWatcherFD = fd
            dirWatcherSource = source
            source.resume()
            LogNotify.log("HexFile watcher: now watching \(dirURL.path)")
        }
    }

    /// Stops the watcher. Call this on shutdown if needed; otherwise it is
    /// torn down automatically when the app is terminated.
    public static func stopWatchingForExternalChanges() {
        watcherQueue.async { stopWatchingInternal() }
    }

    private static func stopWatchingInternal() {
        if let src = dirWatcherSource {
            src.cancel()
        }
        dirWatcherSource = nil
        dirWatcherFD = -1
    }
}
