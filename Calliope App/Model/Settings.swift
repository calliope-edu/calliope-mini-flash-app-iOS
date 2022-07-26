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

    case appVersion = "appVersionInformationPreference"

    case newsURL = "calliopeNewsUrlPreference"

    case defaultHexFileURL = "calliopeDefaultHexFilePreference"
    case blinkingHeartURL = "calliopeBlinkingHeartHexPreference"
    
    case restoreLastMatrix = "restoreLastMatrixPreference" // key for IF to restore the matrix
    case lastMatrix = "lastMatrix" // key for storing the matrix

    case resetSettings = "resetSettingsPreference"
}

public struct Settings {

    static var defaultNewsUrl = NSLocalizedString("https://calliope.cc/forumassets/news.json", comment: "The url for the news json");
    static var defaultRobertaUrl = "https://lab.open-roberta.org/#loadSystem&&calliope2017"
    static var defaultMakecodeUrl = "https://makecode.calliope.cc"
    static var defaultHexFileUrl = "http://calliope.cc/downloads/calliope-demo.hex"
    static var defaultBlinkingHeartUrl = "http://calliope.cc/downloads/blinkendes_herz_calliope_mini.hex"
    static var defaultPlaygroundTemplateUrl = NSLocalizedString("https://calliope.cc/forumassets/snippets.json", comment: "The url for the snippets json");

    static var defaultLocalEditorEnabled = false
    static var defaultMakeCodeEnabled = true
    static var defaultRobertaEnabled = true
    static var defaultPlaygroundsEnabled = UIDevice.current.userInterfaceIdiom != .phone

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

        case .roberta:
            return defaultRobertaEnabled
        case .robertaUrl:
            return defaultRobertaUrl

        case .playgrounds:
            return defaultPlaygroundsEnabled
        case .playgroundTemplateUrl:
            return defaultPlaygroundTemplateUrl

        case .appVersion:
            return defaultAppVersion

        case .newsURL:
            return defaultNewsUrl

        case .defaultHexFileURL:
            return defaultHexFileUrl
        case .blinkingHeartURL:
            return defaultBlinkingHeartUrl
            
        case .restoreLastMatrix:
            return defaultRestoreLastMatrixEnabled
        case .lastMatrix:
            return ""

        case .resetSettings:
            return false
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
