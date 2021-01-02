//
//  SettingsKeys.swift
//  Calliope App
//
//  Created by Tassilo Karge on 29.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

public enum SettingsKey: String, CaseIterable {
    case localEditor = "localEditorOnPreference"
    case makeCode = "makecodeOnPreference"
    case roberta = "robertaOnPreference"
    case playgrounds = "playgroundsOnPreference"

    case makecodeUrl = "makecodeUrlPreference"
    case robertaUrl = "robertaUrlPreference"
    case playgroundTemplateUrl = "playgroundTemplateUrlPreference"

    case appVersion = "appVersionInformationPreference"

    case newsURL = "calliopeNewsUrlPreference"

    case defaultHexFileURL = "calliopeDefaultHexFilePreference"

    case blinkingHeartURL = "calliopeBlinkingHeartHexPreference"
}

public struct Settings {

    static var defaultNewsUrl = "https://calliope.cc/forumassets/news.json"
    static var defaultRobertaUrl = "https://lab.open-roberta.org/#loadSystem&&calliope2017"
    static var defaultMakecodeUrl = "https://makecode.calliope.cc"
    static var defaultHexFileUrl = "https://calliope.cc/media/pages/dateien/hex/-722281028-1582275052/calliope-demo.hex"
    static var defaultBlinkingHeartUrl = "https://calliope.cc/media/pages/ble/-903257399-1566558063/calliope-demo-combined-mit-dfu-20190820.hex"
    static var defaultPlaygroundTemplateUrl = "https://calliope.cc/ble/playgroundSnippets.json"

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
                defaultValue = defaultMakecodeUrl
			case .robertaUrl:
				defaultValue = defaultRobertaUrl
			case .appVersion:
				defaultValue = "1.0"
			case .newsURL:
				defaultValue = defaultNewsUrl
            case .defaultHexFileURL:
                defaultValue = defaultHexFileUrl
            case .blinkingHeartURL: //TODO: replace with correct URL
                defaultValue = defaultBlinkingHeartUrl
            case .playgroundTemplateUrl:
                defaultValue = defaultPlaygroundTemplateUrl
            }
			defaultSettings[key.rawValue] = defaultValue
		}
		UserDefaults.standard.register(defaults: defaultSettings)
	}
    
    static func updateAppVersion() {
        UserDefaults.standard.set(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, forKey: SettingsKey.appVersion.rawValue)
    }
}
