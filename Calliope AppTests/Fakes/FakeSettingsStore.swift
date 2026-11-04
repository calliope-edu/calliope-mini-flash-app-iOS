//
//  FakeSettingsStore.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
@testable import Calliope_App

final class FakeSettingsStore: SettingsStore {
    var restoresLastMatrix = false
    var lastMatrix = ""
}
