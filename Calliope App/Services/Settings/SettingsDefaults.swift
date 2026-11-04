//
//  SettingsDefaults.swift
//  Calliope App
//
//  Created by Tassilo Karge on 29.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

enum SettingsDefaults {

    static let newsUrl = NSLocalizedString("https://calliope.cc/forumassets/news_EN.json", comment: "The url for the news json")
    static let robertaUrl = "https://app.calliope.cc/ios/openroberta/"

    static let makeCodeUrl = "https://makecode.calliope.cc/"
    static let defaultProgramV3Url = "https://go.calliope.cc/downloads/Demov3.hex"
    static let defaultProgramV1AndV2Url = "https://go.calliope.cc/downloads/Demov1.hex"
    static let arcadeUrl = "https://arcade.calliope.cc"
    static let calliopeBlocksUrl = "https://calliope.cc/downloads/blocks.hex"
    static let blocksMiniEditorUrl = "https://blocks.calliope.cc"
    static let microPythonUrl = "https://python.calliope.cc?mobile=true"
    // Cloudflare Pages branch alias of campus `rc-v1.1.3`. Switch to
    // https://campus.calliope.cc once the proxy ships.
    //
    // ORIGIN ONLY — no path. Every campus-hosted editor (the campus home plus
    // the /blocks, /makecode and /python flavours) derives its URL from this
    // one value via `CampusRoute`, so bumping the deployment is a one-line
    // change here.
    static let campusUrl = "https://rc-v1-1-3.calliope-campus.pages.dev"

    static let localEditorEnabled = false
    static let makeCodeEnabled = true
    static let blocksMiniEditorEnabled = UIDevice.current.userInterfaceIdiom != .phone
    static let robertaEnabled = true
    static let arcadeEnabled = true
    static let playgroundsEnabled = UIDevice.current.userInterfaceIdiom != .phone
    static let microPythonEnabled = UIDevice.current.userInterfaceIdiom != .phone
    // Campus uses the native-proxy bridge for BLE/flash, so it works on
    // iPhone too — the legacy iPad-only gate that other editors keep
    // doesn't apply here.
    static let campusEnabled = true
    // The campus-hosted flavours of blocks / MakeCode / python. Same bridge, so
    // same reasoning as `campusEnabled` — no iPad-only gate.
    static let campusBlocksEnabled = true
    static let campusMakeCodeEnabled = true
    static let campusPythonEnabled = true


    static let restoreLastMatrixEnabled = true

    static let appVersion = "1.0"

    static let resetSettingsValue = false

    static func value(for key: SettingsKey) -> Any {
        switch key {

        case .localEditor:
            return localEditorEnabled

        case .makeCode:
            return makeCodeEnabled
        case .makecodeUrl:
            return makeCodeUrl

        case .blocksMiniEditor:
            return blocksMiniEditorEnabled
        case .blocksMiniEditorUrl:
            return blocksMiniEditorUrl
            
        case .roberta:
            return robertaEnabled
        case .robertaUrl:
            return robertaUrl

        case .arcade:
            return arcadeEnabled
        case .arcadeUrl:
            return arcadeUrl
            
        case .microPython:
            return microPythonEnabled
        case .microPythonUrl:
            return microPythonUrl

        case .campus:
            return campusEnabled
        case .campusUrl:
            return campusUrl

        case .campusBlocks:
            return campusBlocksEnabled
        case .campusMakeCode:
            return campusMakeCodeEnabled
        case .campusPython:
            return campusPythonEnabled
            
            
        case .appVersion:
            return appVersion

        case .newsURL:
            return newsUrl

        case .defaultProgramV3Url:
            return defaultProgramV3Url
        case .defaultProgramV1AndV2Url:
            return defaultProgramV1AndV2Url
        case .restoreLastMatrix:
            return restoreLastMatrixEnabled
        case .lastMatrix:
            return ""

        case .resetSettings:
            return resetSettingsValue
        case .calliopeBlocks:
            return true
        case .calliopeBlocksUrl:
            return calliopeBlocksUrl
        }
    }
}
