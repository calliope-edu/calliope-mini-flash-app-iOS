//
//  USBTransferDiagnostics.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct USBTransferDiagnostics {

    let storage: DocumentStorage
    let exportPicker: USBDestinationPicker
    var downloadTimeout: TimeInterval = 15

    // MARK: - Public API

    func programs() -> [URL] {
        let programs = (try? storage.files(withExtensions: ["hex"])) ?? []
        return programs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    // onRejected can arrive after the result, once DAPLink has checked the hex.
    @MainActor
    func run(_ method: USBTransferMethod, program: URL, onRejected: @escaping (String) -> Void) async -> String {
        let start = Date()
        guard await downloadIfNeeded(program) else {
            return "FAILED – program not downloaded from iCloud after \(Self.seconds(since: start))"
        }
        let name = USBCalliope.sanitizedDAPLinkName(from: program.lastPathComponent)
        let bytes = USBHexWriter.byteCount(of: program)
        LogNotify.log("USB diagnostics: \(method.label) with \(program.lastPathComponent) (\(bytes) bytes) as \(name)")

        let outcome = await withCheckedContinuation { continuation in
            method.strategy(exportPicker: exportPicker).transfer(program, named: name, onRejected: onRejected) { outcome in
                continuation.resume(returning: outcome)
            }
        }
        let result: String
        switch outcome {
        case .written:
            result = "Written \(bytes) bytes"
        case .failed:
            result = "FAILED"
        case .cancelledByUser:
            result = "Cancelled"
        }
        LogNotify.log("USB diagnostics: \(method.label) - \(result)")
        return "\(result) (\(Self.seconds(since: start)))"
    }

    // MARK: - Private Helpers

    private func downloadIfNeeded(_ file: URL) async -> Bool {
        storage.startDownloadIfNeeded(file)
        let start = Date()
        while !Self.isDownloaded(file) {
            guard Date().timeIntervalSince(start) < downloadTimeout else { return false }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return true
    }

    // Resource values are cached per URL instance, so polling needs a fresh one.
    private static func isDownloaded(_ file: URL) -> Bool {
        var file = file
        file.removeAllCachedResourceValues()
        let status = (try? file.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus
        return status == nil || status == .current
    }

    private static func seconds(since start: Date) -> String {
        String(format: "%.1f s", Date().timeIntervalSince(start))
    }
}
