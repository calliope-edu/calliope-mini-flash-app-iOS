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

@MainActor
protocol EditorsAndProgramsViewModelProtocol {
    var editors: [EditorTileConfig] { get }
    var alert: AppAlert? { get set }
    var alertBinding: Binding<AppAlert?> { get }

    func uploadDefaultV3Program()
    func uploadDefaultV1And2Program()
    func openFile(result: Result<URL, Error>)
}

class EditorsAndProgramsViewModel: EditorsAndProgramsViewModelProtocol, ObservableObject, @preconcurrency Alertable {

    @Published var editors: [EditorTileConfig] = [
        EditorTileConfig(name: "Calliope mini Blocks", iconName: "editors_blocks_transparent", backgroundColor: Color.white, imageSize: 0.9),
        EditorTileConfig(name: "Makecode", iconName: "editors_makecode"),
        EditorTileConfig(name: "Scan", iconName: "qr_code_scan_button", backgroundColor: Color.white, imageSize: 0.65),
        EditorTileConfig(name: "Micropython", iconName: "editors_python"),
        EditorTileConfig(name: "Arcade", iconName: "editors_swift"),
        EditorTileConfig(name: "Open Roberta Lab", iconName: "editors_nepo")
    ]

    @Published var alert: AppAlert? = nil
    var alertBinding: Binding<AppAlert?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }

    private let uploadViewModel: UploadViewModel
    private let settings: SettingsStore

    init(uploadViewModel: UploadViewModel, settings: SettingsStore) {
        self.uploadViewModel = uploadViewModel
        self.settings = settings
    }

    func uploadDefaultV3Program() {
        let program = DefaultProgram(
            programName: NSLocalizedString("Calliope mini V3", comment: ""),
            url: settings.defaultProgramV3Url
        )
        uploadViewModel.upload(downloadable: program)
    }

    func uploadDefaultV1And2Program() {
        let program = DefaultProgram(
            programName: NSLocalizedString("Calliope mini V1 + 2", comment: ""),
            url: settings.defaultProgramV1AndV2Url
        )
        uploadViewModel.upload(downloadable: program)
    }

    func openFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            if !(url.lastPathComponent.isEmpty) {
                HexFileStoreDialog.showStoreHexUI(alertPublisher: self, uploadViewModel: uploadViewModel, hexFile: url, notSaved: { _ in})
            }
        case .failure(let error):
            LogNotify.error("Program import failed: \(error)")
        }
    }
}

class PreviewEditorsAndProgramsViewModel: EditorsAndProgramsViewModelProtocol, ObservableObject, Alertable {
    @Published var editors: [EditorTileConfig] = [
        EditorTileConfig(name: "Calliope mini Blocks", iconName: "editors_blocks_transparent", backgroundColor: Color.white, imageSize: 0.9),
        EditorTileConfig(name: "Makecode", iconName: "editors_makecode"),
        EditorTileConfig(name: "Scan", iconName: "qr_code_scan_button", backgroundColor: Color.white, imageSize: 0.65),
        EditorTileConfig(name: "Micropython", iconName: "editors_python"),
        EditorTileConfig(name: "Arcade", iconName: "editors_swift"),
        EditorTileConfig(name: "Open Roberta Lab", iconName: "editors_nepo")
    ]

    @Published var alert: AppAlert? = nil
    var alertBinding: Binding<AppAlert?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
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
