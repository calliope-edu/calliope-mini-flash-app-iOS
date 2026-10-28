//
//  StorageDiagnostics.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct StorageDiagnostics {

    let storage: DocumentStorage
    var uploadTimeout: TimeInterval = 30
    var downloadTimeout: TimeInterval = 15

    private typealias Entry = DiagnosticsReport.Entry

    private static let atomicFileName = "diagnostics-atomic.txt"
    private static let inPlaceFileName = "diagnostics-in-place.txt"
    private static let renamedFileName = "diagnostics-in-place-renamed.txt"
    private static let programExtensions = Set(FileExtension.listedInPrograms.map(\.rawValue))

    // MARK: - Public API

    func run() async -> DiagnosticsReport.Section {
        let entries = await Task.detached { await runChecks() }.value
        let section = DiagnosticsReport.Section(title: "Saving", entries: entries)
        LogNotify.log("Storage diagnostics finished:\n\(DiagnosticsReport(sections: [section]).text)")
        return section
    }

    // MARK: - Checks

    private func runChecks() async -> [Entry] {
        let directory: URL
        do {
            directory = try storage.directory()
        } catch {
            return [Entry(label: "Folder", value: Self.failed(error))]
        }
        let isICloud = storage.isICloud
        var entries = [
            Entry(label: "Folder", value: isICloud ? "iCloud" : "Local"),
            Entry(label: "Path", value: directory.path),
        ]

        removeLeftoversOfEarlierRuns()
        let payload = Data("Calliope diagnostics \(Date())".utf8)
        entries += atomicEntries(payload: payload)
        entries += await inPlaceEntries(payload: payload, isICloud: isICloud)
        return entries
    }

    private func atomicEntries(payload: Data) -> [Entry] {
        let (writeEntry, file) = Self.measure("Atomic: write (like CSV)") {
            try storage.save(payload, as: Self.atomicFileName, atomically: true)
        }
        guard let file else { return [writeEntry] }
        return [
            writeEntry,
            readBackEntry("Atomic: read back", file: file, expected: payload),
            deleteEntry("Atomic: delete", file: file),
        ]
    }

    private func inPlaceEntries(payload: Data, isICloud: Bool) async -> [Entry] {
        let (writeEntry, file) = Self.measure("In place: write (like programs)") {
            try storage.save(payload, as: Self.inPlaceFileName, atomically: false)
        }
        guard let file else { return [writeEntry] }

        var entries = [
            writeEntry,
            readBackEntry("In place: read back", file: file, expected: payload),
            Self.measure("In place: list") {
                guard try storage.files(withExtensions: ["txt"]).contains(where: { $0.lastPathComponent == Self.inPlaceFileName }) else {
                    throw DiagnosticsError("file not listed")
                }
            }.0,
        ]
        let (renameEntry, renamed) = Self.measure("In place: rename") {
            try storage.rename(file, to: Self.renamedFileName)
        }
        entries.append(renameEntry)
        let remaining = renamed ?? file

        if isICloud {
            entries.append(Entry(label: "In place: iCloud upload", value: await uploadStatus(of: remaining)))
        }
        entries.append(deleteEntry("In place: delete", file: remaining))
        return entries
    }

    private func readBackEntry(_ label: String, file: URL, expected: Data) -> Entry {
        Self.measure(label) {
            guard try Data(contentsOf: file) == expected else { throw DiagnosticsError("content differs") }
        }.0
    }

    private func deleteEntry(_ label: String, file: URL) -> Entry {
        Self.measure(label) {
            try storage.delete(file)
            guard try !storage.fileExists(named: file.lastPathComponent) else { throw DiagnosticsError("file still there") }
        }.0
    }

    private func uploadStatus(of file: URL) async -> String {
        let start = Date()
        var values: URLResourceValues?
        repeat {
            values = Self.freshValues(of: file, [.ubiquitousItemIsUploadedKey, .ubiquitousItemIsUploadingKey, .ubiquitousItemUploadingErrorKey])
            if let error = values?.ubiquitousItemUploadingError {
                return Self.failed(error)
            }
            if values?.ubiquitousItemIsUploaded == true {
                return "Uploaded after \(Self.seconds(since: start))"
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        } while Date().timeIntervalSince(start) < uploadTimeout
        let state = values?.ubiquitousItemIsUploading == true ? "still uploading" : "not started"
        return "Pending after \(Self.seconds(since: start)), \(state)"
    }

    // MARK: - Private Helpers

    private struct DiagnosticsError: LocalizedError {
        let errorDescription: String?

        init(_ description: String) {
            errorDescription = description
        }
    }

    private func removeLeftoversOfEarlierRuns() {
        let leftovers = (try? storage.files(withExtensions: ["txt"])) ?? []
        for file in leftovers where [Self.atomicFileName, Self.inPlaceFileName, Self.renamedFileName].contains(file.lastPathComponent) {
            try? storage.delete(file)
        }
    }

    private static func measure<T>(_ label: String, _ work: () throws -> T) -> (Entry, T?) {
        let start = Date()
        do {
            let result = try work()
            return (Entry(label: label, value: "OK (\(milliseconds(since: start)))"), result)
        } catch {
            return (Entry(label: label, value: "\(failed(error)) (\(milliseconds(since: start)))"), nil)
        }
    }

    private static func failed(_ error: Error) -> String {
        let nsError = error as NSError
        return "FAILED – \(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
    }

    // Resource values are cached per URL instance, so polling needs a fresh one.
    private static func freshValues(of file: URL, _ keys: Set<URLResourceKey>) -> URLResourceValues? {
        var file = file
        file.removeAllCachedResourceValues()
        return try? file.resourceValues(forKeys: keys)
    }

    private static func isDownloaded(_ file: URL) -> Bool {
        let status = freshValues(of: file, [.ubiquitousItemDownloadingStatusKey])?.ubiquitousItemDownloadingStatus
        return status == nil || status == .current
    }

    private static func milliseconds(since start: Date) -> String {
        "\(Int(Date().timeIntervalSince(start) * 1000)) ms"
    }

    private static func seconds(since start: Date) -> String {
        String(format: "%.1f s", Date().timeIntervalSince(start))
    }
}
