//
//  SettingsKeys.swift
//  Calliope App
//
//  Created by Tassilo Karge on 29.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation
import UIKit

public enum SettingsKey: String, CaseIterable {

    case localEditor = "localEditorOnPreference"

    case makeCode = "makecodeOnPreference"
    case makecodeUrl = "makecodeUrlPreference"

    case roberta = "robertaOnPreference"
    case robertaUrl = "robertaUrlPreference"

    case playgrounds = "playgroundsOnPreference"
    case playgroundTemplateUrl = "playgroundTemplateUrlPreference"
    
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

    case campus = "campusOnPreference"
    case campusUrl = "campusOnUrlPreference"
}

public struct Settings {

    static var defaultNewsUrl = NSLocalizedString("https://calliope.cc/forumassets/news.json", comment: "The url for the news json");
    static var defaultOpenRobertaUrl = "https://app.calliope.cc/ios/openroberta/"

    static var defaultMakecodeUrl = "https://makecode.calliope.cc/beta"
    static var defaultProgramV3 = "https://calliope.cc/downloads/miniV3_start.hex"
    static var defaultProgramV2andV1 = "https://calliope.cc/downloads/calliope-demo.hex"
    static var defaultPlaygroundTemplateUrl = NSLocalizedString("https://calliope.cc/forumassets/snippets.json", comment: "The url for the snippets json")
    static var defaultCalliopeBlocksUrl = "https://calliope.cc/downloads/blocks.hex"
    static var defaultBlocksMiniEditorUrl = "https://blocks.calliope.cc"
    static var defaultMicroPythonUrl = "https://python.calliope.cc?mobile=true"
    static var defaultCampusUrl = "https://campus.calliope.cc"

    static var defaultLocalEditorEnabled = false
    static var defaultMakeCodeEnabled = true
    static var defaultBlocksMiniEditorEnabled = true
    static var defaultRobertaEnabled = true
    static var defaultPlaygroundsEnabled = UIDevice.current.userInterfaceIdiom != .phone
    static var defaultMicroPythonEnabled = true
    static var defaultCampusEnabled = true
    
    
    static var defaultRestoreLastMatrixEnabled = true

    static var defaultAppVersion = "1.0"

    static var defaultResetSettingsValue = false

    private static func defaultForKey(_ key: SettingsKey) -> Any {
        switch key {

        case .localEditor:
            return defaultLocalEditorEnabled

        case .makeCode:
            return defaultMakeCodeEnabled
        case .makecodeUrl:
            return defaultMakecodeUrl

        case .blocksMiniEditor:
            return defaultBlocksMiniEditorEnabled
        case .blocksMiniEditorUrl:
            return defaultBlocksMiniEditorUrl
            
        case .roberta:
            return defaultRobertaEnabled
        case .robertaUrl:
            return defaultOpenRobertaUrl

        case .playgrounds:
            return defaultPlaygroundsEnabled
        case .playgroundTemplateUrl:
            return defaultPlaygroundTemplateUrl
            
        case .microPython:
            return defaultMicroPythonEnabled
        case .microPythonUrl:
            return defaultMicroPythonUrl

        case .campus:
            return defaultCampusEnabled
        case .campusUrl:
            return defaultCampusUrl
            
            
        case .appVersion:
            return defaultAppVersion

        case .newsURL:
            return defaultNewsUrl

        case .defaultProgramV3Url:
            return defaultProgramV3
        case .defaultProgramV1AndV2Url:
            return defaultProgramV2andV1
        case .restoreLastMatrix:
            return defaultRestoreLastMatrixEnabled
        case .lastMatrix:
            return ""

        case .resetSettings:
            return false
        case .calliopeBlocks:
            return true
        case .calliopeBlocksUrl:
            return defaultCalliopeBlocksUrl
        }
    }

    static func registerDefaults() {
        var defaultSettings: [String: Any] = [:]
        for key in SettingsKey.allCases {
            let defaultValue = defaultForKey(key)
            defaultSettings[key.rawValue] = defaultValue
        }
        UserDefaults.standard.register(defaults: defaultSettings)
    }

    static func updateAppVersion() {
        let versionString: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        UserDefaults.standard.set(versionString, forKey: SettingsKey.appVersion.rawValue)
    }


    static func resetSettingsIfRequired() {
        if UserDefaults.standard.bool(forKey: SettingsKey.resetSettings.rawValue) {
            resetSettings()
        }
    }

    private static func resetSettings() {
        SettingsKey.allCases.forEach {
            UserDefaults.standard.removeObject(forKey: $0.rawValue)
        }
    }
}
