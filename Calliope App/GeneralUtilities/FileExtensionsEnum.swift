//
//  DataExtensions.swift
//  Calliope App
//
//  Created by Calliope on 02.07.25.
//  Copyright © 2025 calliope. All rights reserved.
//

enum FileExtension: String, CaseIterable {
    case hex = "hex"
    case json = "json"
    case html = "html"
    /// MicroPython source, saved from the Python editor.
    case py = "py"
    /// Scratch/Blocks project, saved from the Blocks editor.
    case sb3 = "sb3"
    /// Image saved from an editor (e.g. an Arcade screenshot).
    case png = "png"

    /// Extensions that appear in the programs list of "Editors and Programs".
    ///
    /// Hex only. Python sources, Blocks projects and Arcade images are saved
    /// through the system save dialog to wherever the user picks ("Calliope mini",
    /// "Calliope mini App" in iCloud, or any other location) — they are user
    /// documents, not programs that can be transferred to the mini.
    static let listedInPrograms: [FileExtension] = [.hex]

    /// Types an editor can hand to the system save dialog.
    static let savableFromEditor: [FileExtension] = [.py, .sb3, .png]

    /// Only a hex file can be written to the mini — a Python source, a Blocks
    /// project or an image is stored for later use but never transferred.
    var isFlashable: Bool {
        return self == .hex
    }
}
