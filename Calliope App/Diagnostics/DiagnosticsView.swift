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
                }
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

    // Without the full-width shape only the icon and text of the row react to taps.
    private func rowLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}
