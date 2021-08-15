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
    
    case resetSettings = "resetSettingsPreference"
    
}


public struct Settings {

    static var defaultNewsUrl = "https://calliope.cc/forumassets/news.json"
    static var defaultRobertaUrl = "https://lab.open-roberta.org/#loadSystem&&calliope2017"
    static var defaultMakecodeUrl = "https://makecode.calliope.cc"
    static var defaultHexFileUrl = "http://calliope.cc/downloads/calliope-demo.hex"
    static var defaultBlinkingHeartUrl = "http://calliope.cc/downloads/blinkendes_herz_calliope_mini.hex"
    static var defaultPlaygroundTemplateUrl = "https://calliope.cc/forumassets/snippets.json"

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
            case .blinkingHeartURL:
                defaultValue = defaultBlinkingHeartUrl
            case .playgroundTemplateUrl:
                defaultValue = defaultPlaygroundTemplateUrl
            case .resetSettings:
                defaultValue = false
            }
			defaultSettings[key.rawValue] = defaultValue
		}
		UserDefaults.standard.register(defaults: defaultSettings)
        
	}
    
    static func updateAppVersion() {
        UserDefaults.standard.set(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, forKey: SettingsKey.appVersion.rawValue)
    }
    
    public static func resetIfNecessary() {
        if (UserDefaults.standard.bool(forKey: SettingsKey.resetSettings.rawValue)) {
            reset()
        }
    }
    
    private static func reset() {
        SettingsKey.allCases.forEach { UserDefaults.standard.removeObject(forKey: $0.rawValue) }
    }
    
}
