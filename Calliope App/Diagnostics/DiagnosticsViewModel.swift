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

    @Published private(set) var report: DiagnosticsReport?
    @Published private(set) var didCopy = false

    private let diagnostics: DeviceDiagnostics

    init(diagnostics: DeviceDiagnostics) {
        self.diagnostics = diagnostics
    }

    // MARK: - Public API

    func load() async {
        report = await diagnostics.collect()
        LogNotify.log("Diagnostics report created")
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
