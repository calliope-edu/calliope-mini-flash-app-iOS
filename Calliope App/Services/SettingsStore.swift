//
//  SettingsStore.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol SettingsStore: AnyObject {
    var restoresLastMatrix: Bool { get }
    var lastMatrix: String { get set }
    var defaultProgramV3Url: String { get }
    var defaultProgramV1AndV2Url: String { get }
    var makeCodeUrl: URL? { get }
    var robertaUrl: URL? { get }
    var microPythonUrl: URL? { get }
    var newsUrl: URL? { get }
}

final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // Must run before anything reads a setting.
    func prepareForLaunch(appVersion: String?) {
        defaults.register(defaults: Dictionary(uniqueKeysWithValues: SettingsKey.allCases.map { ($0.rawValue, Settings.defaultValue(for: $0)) }))
        if defaults.bool(forKey: SettingsKey.resetSettings.rawValue) {
            SettingsKey.allCases.forEach { defaults.removeObject(forKey: $0.rawValue) }
        }
        defaults.set(appVersion, forKey: SettingsKey.appVersion.rawValue)
    }

    var restoresLastMatrix: Bool {
        defaults.bool(forKey: SettingsKey.restoreLastMatrix.rawValue)
    }

    var lastMatrix: String {
        get { defaults.string(forKey: SettingsKey.lastMatrix.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: SettingsKey.lastMatrix.rawValue) }
    }

    var defaultProgramV3Url: String {
        defaults.string(forKey: SettingsKey.defaultProgramV3Url.rawValue) ?? Settings.defaultProgramV3
    }

    var defaultProgramV1AndV2Url: String {
        defaults.string(forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue) ?? Settings.defaultProgramV2andV1
    }

    var makeCodeUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.makecodeUrl.rawValue) ?? Settings.defaultMakecodeUrl)
    }

    var robertaUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.robertaUrl.rawValue) ?? Settings.defaultOpenRobertaUrl)
    }

    var microPythonUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.microPythonUrl.rawValue) ?? Settings.defaultMicroPythonUrl)
    }

    var newsUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.newsURL.rawValue) ?? Settings.defaultNewsUrl)
    }
}
