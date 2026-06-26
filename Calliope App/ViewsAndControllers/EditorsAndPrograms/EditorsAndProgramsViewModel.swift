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
}

class EditorsAndProgramsViewModel: ObservableObject {
    @Published var editors: [EditorTileConfig] = [
        EditorTileConfig(name: "Makecode", iconName: "editors_makecode"),
        EditorTileConfig(name: "Open Roberta Lab", iconName: "editors_nepo"),
        EditorTileConfig(name: "Calliope mini Blocks", iconName: "editors_blocks_transparent"),
        EditorTileConfig(name: "Micropython", iconName: "editors_python"),
        EditorTileConfig(name: "Arcade (USB only)", iconName: "editors_swift")
    ]
    
    @Published var programs: [ProgramTileConfig] = [
        ProgramTileConfig(name: "Test 1", lastUsed: Date.now),
        ProgramTileConfig(name: "Test 2", lastUsed: Date.now.addingTimeInterval(100)),
    ]
}
