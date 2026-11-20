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
    @Published private var usbTransferEntries: [DiagnosticsReport.Entry] = []
    @Published private(set) var isTestingUSBTransfer = false
    @Published private(set) var programs: [URL] = []
    @Published var selectedProgram: URL?
    @Published var selectedUSBTransferMethod: USBTransferMethod = .placeholderThenWrite
    @Published var alert: AppAlert?

    private let diagnostics: DeviceDiagnostics
    private let storageDiagnostics: StorageDiagnostics
    private let usbTransferDiagnostics: USBTransferDiagnostics

    var folderPicker: DiagnosticsFolderPicker {
        usbTransferDiagnostics.folderPicker
    }

    init(diagnostics: DeviceDiagnostics, storageDiagnostics: StorageDiagnostics, usbTransferDiagnostics: USBTransferDiagnostics) {
        self.diagnostics = diagnostics
        self.storageDiagnostics = storageDiagnostics
        self.usbTransferDiagnostics = usbTransferDiagnostics
    }

    // MARK: - Public API

    var report: DiagnosticsReport? {
        guard let deviceReport else { return nil }
        let usbTransferSection = usbTransferEntries.isEmpty ? nil : DiagnosticsReport.Section(title: "USB transfer", entries: usbTransferEntries)
        return DiagnosticsReport(sections: deviceReport.sections + [storageSection, usbTransferSection].compactMap { $0 })
    }

    func load() async {
        reloadPrograms()
        deviceReport = await diagnostics.collect()
        LogNotify.log("Diagnostics report created")
    }

    func reloadPrograms() {
        programs = usbTransferDiagnostics.programs()
        if selectedProgram.map(programs.contains) != true {
            selectedProgram = programs.first
        }
    }

    func testUSBTransfer() {
        guard !isTestingUSBTransfer, let program = selectedProgram else { return }
        isTestingUSBTransfer = true
        let method = selectedUSBTransferMethod
        let label = "#\(usbTransferEntries.count + 1) \(method.label), \(program.lastPathComponent)"
        Task {
            let result = await usbTransferDiagnostics.run(method, program: program) { [weak self] reason in
                Task { @MainActor in
                    self?.appendToUSBTransferEntry(label, "DAPLink rejected: \(reason)")
                }
            }
            usbTransferEntries.append(DiagnosticsReport.Entry(label: label, value: result.summary))
            isTestingUSBTransfer = false
            // Nothing was sent to the mini, so there is nothing to check.
            if result.outcome != .cancelledByUser {
                askWhetherProgramRuns(label: label)
            }
        }
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

    // MARK: - Private Helpers

    private func askWhetherProgramRuns(label: String) {
        let answer = { [weak self] (text: String) in
            LogNotify.log("USB diagnostics: \(label) - program runs: \(text)")
            self?.appendToUSBTransferEntry(label, "Program runs: \(text)")
        }
        alert = AppAlert(
            title: NSLocalizedString("Does the Calliope mini run the program?", comment: ""),
            message: NSLocalizedString("Check the Calliope mini and choose what it does now.", comment: ""),
            actions: [
                StandardAlertAction(NSLocalizedString("Yes, it runs the program", comment: "")) { answer("yes") },
                StandardAlertAction(NSLocalizedString("No, it keeps the old program", comment: "")) { answer("no, old program") },
                StandardAlertAction(NSLocalizedString("No, it shows an error", comment: "")) { answer("no, error shown") },
            ]
        )
    }

    private func appendToUSBTransferEntry(_ label: String, _ text: String) {
        guard let index = usbTransferEntries.firstIndex(where: { $0.label == label }) else { return }
        let entry = usbTransferEntries[index]
        usbTransferEntries[index] = DiagnosticsReport.Entry(label: label, value: "\(entry.value) – \(text)")
    }
}
