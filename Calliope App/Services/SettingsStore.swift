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
}
