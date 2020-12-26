//
//  SettingsKeys.swift
//  Calliope App
//
//  Created by Tassilo Karge on 29.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

public struct Settings {
	static func registerDefaults() {
		var defaultSettings: [String: Any] = [:]
		for key in SettingsKey.allCases {
			let defaultValue: Any
			switch key {
			case .localEditor:
				defaultValue = false
			case .makeCode:
				defaultValue = true
			case .roberta:
				defaultValue = true
			case .playgrounds:
				defaultValue = true
			case .makecodeUrl:
                defaultValue = "https://makecode.calliope.cc"
			case .robertaUrl:
				defaultValue = "https://lab.open-roberta.org/#loadSystem&&calliope2017"
			case .appVersion:
				defaultValue = "1.0"
			case .newsURL:
				defaultValue = "https://calliope.cc/forumassets/news.json"
            case .defaultHexFileURL:
                defaultValue = "https://calliope.cc/media/pages/ble/-903257399-1566558063/calliope-demo-combined-mit-dfu-20190820.hex"
            case .blinkingHeartURL: //TODO: replace with correct URL
                defaultValue = "https://calliope.cc/media/pages/ble/-903257399-1566558063/calliope-demo-combined-mit-dfu-20190820.hex"
            }
			defaultSettings[key.rawValue] = defaultValue
		}
		UserDefaults.standard.register(defaults: defaultSettings)
	}
    
    static func updateAppVersion() {
        UserDefaults.standard.set(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, forKey: SettingsKey.appVersion.rawValue)
    }
}

public enum SettingsKey: String, CaseIterable {
	case localEditor = "localEditorOnPreference"
	case makeCode = "makecodeOnPreference"
	case roberta = "robertaOnPreference"
	case playgrounds = "playgroundsOnPreference"

	case makecodeUrl = "makecodeUrlPreference"
	case robertaUrl = "robertaUrlPreference"

	case appVersion = "appVersionInformationPreference"

	case newsURL = "calliopeNewsUrlPreference"
    
    case defaultHexFileURL = "calliopeDefaultHexFilePreference"
    
    case blinkingHeartURL = "calliopeBlinkingHeartHexPreference"
}
