//
//  EditorsAndProgramsViewModel.swift
//  Calliope App
//
//  Created by Calliope on 19.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct EditorTileConfig {
    let name: String
    let iconName: String
}

struct ProgramTileConfig {
    let name: String
    let lastUsed: Date
    let hexFile: HexFile
}

protocol EditorsAndProgramsViewModelProtocol {
    var editors: [EditorTileConfig] { get }
    var programs: [ProgramTileConfig] { get }

    func openEditor(editor: EditorTileConfig)
    func downloadProgram(program: ProgramTileConfig)
    func uploadDefaultV3Program()
    func uploadDefaultV1And2Program()
    func scanQRCode()
    func openFile()
}

class EditorsAndProgramsViewModel: EditorsAndProgramsViewModelProtocol, ObservableObject {
    let openEditor: (_ editor: EditorTileConfig) -> Void
    let uploadDownloadableProgram: (_ program: DownloadableHexFile) -> Void
    let openQRCodeView: () -> Void
    let openFileDialog: () -> Void

    @Published var editors: [EditorTileConfig] = [
        EditorTileConfig(name: "Makecode", iconName: "editors_makecode"),
        EditorTileConfig(name: "Open Roberta Lab", iconName: "editors_nepo"),
        EditorTileConfig(name: "Calliope mini Blocks", iconName: "editors_blocks_transparent"),
        EditorTileConfig(name: "Micropython", iconName: "editors_python"),
        EditorTileConfig(name: "Arcade (USB only)", iconName: "editors_swift"),
    ]

    @Published var programs: [ProgramTileConfig] = []

    var programSubscription: NSObjectProtocol!

    func loadPrograms() {
        programs = []
        do {
            programs = try HexFileManager.stored().map { ProgramTileConfig(name: $0.name, lastUsed: $0.date, hexFile: $0) }
        } catch {
            LogNotify.error("Could not load programs \(error)")
        }
    }

    init(
        openEditor: @escaping (_ editor: EditorTileConfig) -> Void,
        uploadDownloadableProgram: @escaping (_ program: DownloadableHexFile) -> Void,
        openQRCodeView: @escaping () -> Void,
        openFileDialog: @escaping () -> Void
    ) {
        self.openEditor = openEditor
        self.uploadDownloadableProgram = uploadDownloadableProgram
        self.openQRCodeView = openQRCodeView
        self.openFileDialog = openFileDialog

        loadPrograms()
        programSubscription = NotificationCenter.default.addObserver(
            forName: NotificationConstants.hexFileChanged,
            object: nil,
            queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self!.loadPrograms()
                }
            }
        )

    }

    func openEditor(editor: EditorTileConfig) {
        openEditor(editor)
    }

    func downloadProgram(program: ProgramTileConfig) {
        print("Trying to open program \(program.name)")
    }

    func uploadDefaultV3Program() {
        let program = DefaultProgram(
            programName: NSLocalizedString("Calliope mini V3", comment: ""),
            url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV3Url.rawValue)!
        )
        uploadDownloadableProgram(program)
    }

    func uploadDefaultV1And2Program() {
        let program = DefaultProgram(
            programName: NSLocalizedString("Calliope mini V1 + 2", comment: ""),
            url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue)!
        )
        uploadDownloadableProgram(program)
    }

    func scanQRCode() {
        openQRCodeView()
    }

    func openFile() {
        openFileDialog()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(programSubscription!)
    }
}

class PreviewEditorsAndProgramsViewModel: EditorsAndProgramsViewModelProtocol, ObservableObject {
    @Published var editors: [EditorTileConfig] = [
        EditorTileConfig(name: "Makecode", iconName: "editors_makecode"),
        EditorTileConfig(name: "Open Roberta Lab", iconName: "editors_nepo"),
        EditorTileConfig(name: "Calliope mini Blocks", iconName: "editors_blocks_transparent"),
        EditorTileConfig(name: "Micropython", iconName: "editors_python"),
        EditorTileConfig(name: "Arcade (USB only)", iconName: "editors_swift"),
    ]

    @Published var programs: [ProgramTileConfig] = [
        ProgramTileConfig(name: "Test 1", lastUsed: Date.now, hexFile: HexFile(url: URL(fileURLWithPath: ""), name: "", date: Date.now)),
        ProgramTileConfig(
            name: "Test 2",
            lastUsed: Date.now.addingTimeInterval(100),
            hexFile: HexFile(url: URL(fileURLWithPath: ""), name: "", date: Date.now.addingTimeInterval(100))
        ),
    ]

    func openEditor(editor: EditorTileConfig) {
        print("Trying to open editor \(editor.name)")
    }

    func downloadProgram(program: ProgramTileConfig) {
        print("Trying to open program \(program.name)")
    }

    func uploadDefaultV3Program() {
        print("Trying to upload default v3 program")
    }

    func uploadDefaultV1And2Program() {
        print("Trying to upload default v1 and v2 program")
    }

    func scanQRCode() {
        print("Trying to scan QR code")
    }

    func openFile() {
        print("Trying to open file")
    }
}
