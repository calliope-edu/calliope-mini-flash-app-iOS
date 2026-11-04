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
    var blocksMiniEditorUrl: URL? { get }
    var campusUrl: URL? { get }
}

final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // Must run before anything reads a setting.
    func prepareForLaunch(appVersion: String?) {
        defaults.register(defaults: Dictionary(uniqueKeysWithValues: SettingsKey.allCases.map { ($0.rawValue, SettingsDefaults.value(for: $0)) }))
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
        defaults.string(forKey: SettingsKey.defaultProgramV3Url.rawValue) ?? SettingsDefaults.defaultProgramV3Url
    }

    var defaultProgramV1AndV2Url: String {
        defaults.string(forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue) ?? SettingsDefaults.defaultProgramV1AndV2Url
    }

    var makeCodeUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.makecodeUrl.rawValue) ?? SettingsDefaults.makeCodeUrl)
    }

    var robertaUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.robertaUrl.rawValue) ?? SettingsDefaults.robertaUrl)
    }

    var microPythonUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.microPythonUrl.rawValue) ?? SettingsDefaults.microPythonUrl)
    }

    var newsUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.newsURL.rawValue) ?? SettingsDefaults.newsUrl)
    }

    var blocksMiniEditorUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.blocksMiniEditorUrl.rawValue) ?? SettingsDefaults.blocksMiniEditorUrl)
    }

    var campusUrl: URL? {
        URL(string: defaults.string(forKey: SettingsKey.campusUrl.rawValue) ?? SettingsDefaults.campusUrl)
    }
}
