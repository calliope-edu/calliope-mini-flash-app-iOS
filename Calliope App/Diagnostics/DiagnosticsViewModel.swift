//
//  DiagnosticsViewModel.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import UIKit
import Foundation

@MainActor
final class DiagnosticsViewModel: ObservableObject {

    @Published private var deviceReport: DiagnosticsReport?
    @Published private var storageSection: DiagnosticsReport.Section?
    @Published private(set) var didCopy = false
    @Published private(set) var isTestingStorage = false

    private let diagnostics: DeviceDiagnostics
    private let storageDiagnostics: StorageDiagnostics

    init(diagnostics: DeviceDiagnostics, storageDiagnostics: StorageDiagnostics) {
        self.diagnostics = diagnostics
        self.storageDiagnostics = storageDiagnostics
    }

    // MARK: - Public API

    var report: DiagnosticsReport? {
        guard let deviceReport else { return nil }
        return DiagnosticsReport(sections: deviceReport.sections + [storageSection].compactMap { $0 })
    }

    func load() async {
        deviceReport = await diagnostics.collect()
        LogNotify.log("Diagnostics report created")
    }

    func testStorage() {
        guard !isTestingStorage else { return }
        isTestingStorage = true
        Task {
            storageSection = await storageDiagnostics.run()
            isTestingStorage = false
        }
    }

    func copyReport() {
        guard let report else { return }
        UIPasteboard.general.string = report.text
        didCopy = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            didCopy = false
        }
    }
}
