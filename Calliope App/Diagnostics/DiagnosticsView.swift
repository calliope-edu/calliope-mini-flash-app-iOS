//
//  DiagnosticsView.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

struct DiagnosticsView: View {
    @StateObject private var viewModel: DiagnosticsViewModel

    init(viewModel: DiagnosticsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Diagnostics")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.load()
        }
        .modifier(DiagnosticsFolderPickerModifier(picker: viewModel.folderPicker))
        .modifier(AlertModifier(alert: $viewModel.alert))
    }

    @ViewBuilder
    private var content: some View {
        if let report = viewModel.report {
            List {
                Section {
                    Text("You can share this report using “Share” or “Copy”.")
                    ShareLink(item: report.text) {
                        rowLabel("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        viewModel.copyReport()
                    } label: {
                        if viewModel.didCopy {
                            rowLabel("Copied", systemImage: "checkmark")
                        } else {
                            rowLabel("Copy", systemImage: "doc.on.doc")
                        }
                    }
                    Button {
                        viewModel.testStorage()
                    } label: {
                        if viewModel.isTestingStorage {
                            HStack {
                                ProgressView()
                                Text("Testing saving…")
                            }
                        } else {
                            rowLabel("Test saving", systemImage: "externaldrive.badge.checkmark")
                        }
                    }
                    .disabled(viewModel.isTestingStorage)
                }
                usbTransferSection
                ForEach(report.sections) { section in
                    Section(section.title) {
                        ForEach(section.entries) { entry in
                            LabeledContent(entry.label) {
                                Text(verbatim: entry.value)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        } else {
            ProgressView("Collecting information…")
        }
    }

    private var usbTransferSection: some View {
        Section {
            Text("Connect the Calliope mini via USB, choose a program and a method, then pick the MINI drive when asked.")
            Picker("Program", selection: $viewModel.selectedProgram) {
                ForEach(viewModel.programs, id: \.self) { program in
                    Text(verbatim: program.lastPathComponent).tag(Optional(program))
                }
            }
            Picker("Method", selection: $viewModel.selectedUSBTransferMethod) {
                ForEach(USBTransferMethod.allCases) { method in
                    Text(verbatim: method.label).tag(method)
                }
            }
            .pickerStyle(.inline)
            Button {
                viewModel.testUSBTransfer()
            } label: {
                if viewModel.isTestingUSBTransfer {
                    HStack {
                        ProgressView()
                        Text("Testing USB transfer…")
                    }
                } else {
                    rowLabel("Test USB transfer", systemImage: "cable.connector")
                }
            }
            .disabled(viewModel.isTestingUSBTransfer || viewModel.selectedProgram == nil)
        } header: {
            Text("USB transfer")
        }
        .onAppear {
            viewModel.reloadPrograms()
        }
    }

    // Without the full-width shape only the icon and text of the row react to taps.
    private func rowLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}
