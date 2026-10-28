//
//  DiagnosticsReport.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct DiagnosticsReport: Equatable {

    struct Entry: Equatable, Identifiable {
        let label: String
        let value: String

        var id: String { label }
    }

    struct Section: Equatable, Identifiable {
        let title: String
        let entries: [Entry]

        var id: String { title }
    }

    let sections: [Section]

    var text: String {
        sections
            .map { section in
                let lines = section.entries.map { "\($0.label): \($0.value)" }
                return (["## \(section.title)"] + lines).joined(separator: "\n")
            }
            .joined(separator: "\n\n")
    }
}
