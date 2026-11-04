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
    var defaultProgramV3Url = "https://example.com/v3.hex"
    var defaultProgramV1AndV2Url = "https://example.com/v1.hex"
    var makeCodeUrl = URL(string: "https://makecode.example.com/")
    var robertaUrl = URL(string: "https://roberta.example.com/")
    var microPythonUrl = URL(string: "https://python.example.com/")
}
