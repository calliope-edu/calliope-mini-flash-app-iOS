//
//  HexDocument.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct HexDocument: FileDocument {
    static let hexType = UTType(filenameExtension: "hex") ?? .data
    static var readableContentTypes: [UTType] { [hexType] }

    let contents: Data

    init(contents: Data) {
        self.contents = contents
    }

    init(configuration: ReadConfiguration) throws {
        contents = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: contents)
    }
}
