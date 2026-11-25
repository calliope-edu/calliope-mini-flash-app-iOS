//
//  SettingsKey.swift
//  Calliope App
//
//  Created by Tassilo Karge on 29.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

public enum SettingsKey: String, CaseIterable {

    case localEditor = "localEditorOnPreference"

    case makeCode = "makecodeOnPreference"
    case makecodeUrl = "makecodeUrlPreference"

    case roberta = "robertaOnPreference"
    case robertaUrl = "robertaUrlPreference"

    case arcade = "arcadeOnPreference"
    case arcadeUrl = "arcadeUrlPreference"
    
    case blocksMiniEditor = "blocksMiniOnPreferences"
    case blocksMiniEditorUrl = "blocksMiniUrlPreference"

    case appVersion = "appVersionInformationPreference"

    case newsURL = "calliopeNewsUrlPreference"

    case defaultProgramV3Url = "calliopeDefaultProgramV3HexPreference"
    case defaultProgramV1AndV2Url = "calliopeDefaultProgramV1andV2HexPreference"

    case restoreLastMatrix = "restoreLastMatrixPreference" // key for IF to restore the matrix
    case lastMatrix = "lastMatrix" // key for storing the matrix

    case resetSettings = "resetSettingsPreference"

    case calliopeBlocks = "calliopeBlocksOnPreference"
    case calliopeBlocksUrl = "calliopeBlocksUrlPreference"
    
    case microPython = "microPythonOnPreference"
    case microPythonUrl = "microPythonUrlPreference"
}
