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
}

final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
}
