//
//  EditorsAndProgramsViewModel.swift
//  Calliope App
//
//  Created by Calliope on 19.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct EditorTileConfig {
    let name: String
    let iconName: String
    let backgroundColor: Color?
    let imageSize: Double
    
    init(name: String, iconName: String, backgroundColor: Color? = nil, imageSize: Double = 1.0) {
        self.name = name
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        self.imageSize = imageSize
    }
}

struct ProgramTileConfig: Identifiable {
    let id = UUID()
    let name: String
    let lastUsed: Date
    let hexFile: HexFile
}

protocol EditorsAndProgramsViewModelProtocol {
    var editors: [EditorTileConfig] { get }
    var programs: [ProgramTileConfig] { get }
    var alert: (any AppAlert)? { get set }
    var alertBinding: Binding<(any AppAlert)?> { get }

    func downloadProgram(program: ProgramTileConfig)
    func renameProgram(program: ProgramTileConfig)
    func deleteProgram(program: ProgramTileConfig)
    func uploadDefaultV3Program()
    func uploadDefaultV1And2Program()
    func openFile(result: Result<URL, Error>)
}

class EditorsAndProgramsViewModel: EditorsAndProgramsViewModelProtocol, ObservableObject, Alertable, CanShowProgess {

    @Published var editors: [EditorTileConfig] = [
        EditorTileConfig(name: "Makecode", iconName: "editors_makecode"),
        EditorTileConfig(name: "Open Roberta Lab", iconName: "editors_nepo"),
        EditorTileConfig(name: "Calliope mini Blocks", iconName: "editors_blocks_transparent", backgroundColor: Color.white, imageSize: 0.9),
        EditorTileConfig(name: "Micropython", iconName: "editors_python"),
        EditorTileConfig(name: "Arcade (USB only)", iconName: "editors_swift"),
        EditorTileConfig(name: "Scan", iconName: "qr_code_scan_button", backgroundColor: Color.white, imageSize: 0.8)
    ]

    @Published var programs: [ProgramTileConfig] = []

    @Published var alert: (any AppAlert)? = nil
    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }
    
    var progress: (any ProgressAlert)?

    var programSubscription: NSObjectProtocol!

    func loadPrograms() {
        programs = []
        do {
            programs = try HexFileManager.stored().map { ProgramTileConfig(name: $0.name, lastUsed: $0.date, hexFile: $0) }
        } catch {
            LogNotify.error("Could not load programs \(error)")
        }
    }

    init() {
        loadPrograms()
        programSubscription = NotificationCenter.default.addObserver(
            forName: NotificationConstants.hexFileChanged,
            object: nil,
            queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self!.loadPrograms()
                    print(self!.programs.count)
                }
            }
        )

    }

    func downloadProgram(program: ProgramTileConfig) {
        FirmwareUploadSwiftUI.showUploadUI(alertPublisher: self, program: program.hexFile, name: program.name) {
            MatrixConnectionViewModel.instance.connect()
        }
    }

    func renameProgram(program: ProgramTileConfig) {
        let alert = RenameProgramAlert(defaultName: program.name, onRename: { newName in
                if newName != "" {
                    var renamableProgram = program.hexFile
                    renamableProgram.name = newName
                    if renamableProgram.name != newName {
                        //rename was not successful
                        let failedAlert = RenameFailedAlert(oldName: renamableProgram.name, newName: newName)
                        self.alert = failedAlert
                    }
                }
        })
        self.alert = alert
    }

    func deleteProgram(program: ProgramTileConfig) {
        let hexFile = program.hexFile
        self.alert = DeleteProgramAlert(program: hexFile) {
            do {
                try HexFileManager.delete(file: hexFile)
            } catch {
                self.alert = DeleteProgramFailedAlert(program: hexFile, error: error)
            }
        }
    }

    func uploadDefaultV3Program() {
        let program = DefaultProgram(
            programName: NSLocalizedString("Calliope mini V3", comment: ""),
            url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV3Url.rawValue)!
        )
        FirmwareUploadSwiftUI.showUIForDownloadableProgram(alertPublisher: self, program: program)
    }

    func uploadDefaultV1And2Program() {
        let program = DefaultProgram(
            programName: NSLocalizedString("Calliope mini V1 + 2", comment: ""),
            url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue)!
        )
        FirmwareUploadSwiftUI.showUIForDownloadableProgram(alertPublisher: self, program: program)
    }

    func openFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            if !(url.lastPathComponent.isEmpty) {
                HexFileStoreDialogSwiftUI.showStoreHexUI(alertPublisher: self, hexFile: url, notSaved: { _ in})
            }
        case .failure(let error):
            LogNotify.error("Program import failed: \(error)")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(programSubscription!)
    }
}

class PreviewEditorsAndProgramsViewModel: EditorsAndProgramsViewModelProtocol, ObservableObject, Alertable {
    @Published var editors: [EditorTileConfig] = [
        EditorTileConfig(name: "Makecode", iconName: "editors_makecode"),
        EditorTileConfig(name: "Open Roberta Lab", iconName: "editors_nepo"),
        EditorTileConfig(name: "Calliope mini Blocks", iconName: "editors_blocks_transparent", backgroundColor: Color.white, imageSize: 0.9),
        EditorTileConfig(name: "Micropython", iconName: "editors_python"),
        EditorTileConfig(name: "Arcade (USB only)", iconName: "editors_swift"),
        EditorTileConfig(name: "Scan", iconName: "qr_code_scan_button", backgroundColor: Color.white, imageSize: 0.7)
    ]

    @Published var programs: [ProgramTileConfig] = [
        ProgramTileConfig(name: "Test 1", lastUsed: Date.now, hexFile: HexFile(url: URL(fileURLWithPath: ""), name: "", date: Date.now)),
        ProgramTileConfig(
            name: "Test 2",
            lastUsed: Date.now.addingTimeInterval(100),
            hexFile: HexFile(url: URL(fileURLWithPath: ""), name: "", date: Date.now.addingTimeInterval(100))
        ),ProgramTileConfig(name: "Test 1", lastUsed: Date.now, hexFile: HexFile(url: URL(fileURLWithPath: ""), name: "", date: Date.now)),
        ProgramTileConfig(
            name: "Test 2",
            lastUsed: Date.now.addingTimeInterval(100),
            hexFile: HexFile(url: URL(fileURLWithPath: ""), name: "", date: Date.now.addingTimeInterval(100))
        ),ProgramTileConfig(name: "Test 1", lastUsed: Date.now, hexFile: HexFile(url: URL(fileURLWithPath: ""), name: "", date: Date.now)),
        ProgramTileConfig(
            name: "Test 2",
            lastUsed: Date.now.addingTimeInterval(100),
            hexFile: HexFile(url: URL(fileURLWithPath: ""), name: "", date: Date.now.addingTimeInterval(100))
        ),
    ]

    @Published var alert: (any AppAlert)? = nil
    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }

    func downloadProgram(program: ProgramTileConfig) {
        print("Trying to open program \(program.name)")
    }

    func renameProgram(program: ProgramTileConfig) {
        print("Trying to rename program \(program.name)")
    }

    func deleteProgram(program: ProgramTileConfig) {
        print("Trying to delete program \(program.name)")
    }

    func uploadDefaultV3Program() {
        print("Trying to upload default v3 program")
    }

    func uploadDefaultV1And2Program() {
        print("Trying to upload default v1 and v2 program")
    }

    func openFile(result: Result<URL, Error>) {
        print("Trying to open file")
    }
}
