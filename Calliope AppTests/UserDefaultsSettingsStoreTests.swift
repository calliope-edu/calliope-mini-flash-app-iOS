//
//  UserDefaultsSettingsStoreTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

final class UserDefaultsSettingsStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: UserDefaultsSettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "UserDefaultsSettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = UserDefaultsSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testPreparingForLaunchRegistersTheDefaults() {
        store.prepareForLaunch(appVersion: nil)

        XCTAssertTrue(store.restoresLastMatrix)
    }

    func testPreparingForLaunchResetsTheSettingsWhenRequested() {
        store.lastMatrix = "1111100000111110000011111"
        defaults.set(false, forKey: SettingsKey.restoreLastMatrix.rawValue)
        defaults.set(true, forKey: SettingsKey.resetSettings.rawValue)

        store.prepareForLaunch(appVersion: nil)

        XCTAssertEqual(store.lastMatrix, "")
        XCTAssertTrue(store.restoresLastMatrix)
        XCTAssertFalse(defaults.bool(forKey: SettingsKey.resetSettings.rawValue))
    }

    func testPreparingForLaunchKeepsTheSettingsWithoutAResetRequest() {
        store.lastMatrix = "1111100000111110000011111"

        store.prepareForLaunch(appVersion: nil)

        XCTAssertEqual(store.lastMatrix, "1111100000111110000011111")
    }

    func testPreparingForLaunchStoresTheAppVersionForTheSettingsApp() {
        store.prepareForLaunch(appVersion: "4.2.0")

        XCTAssertEqual(defaults.string(forKey: SettingsKey.appVersion.rawValue), "4.2.0")
    }

    func testRestoresLastMatrixReflectsThePreference() {
        defaults.set(true, forKey: SettingsKey.restoreLastMatrix.rawValue)
        XCTAssertTrue(store.restoresLastMatrix)

        defaults.set(false, forKey: SettingsKey.restoreLastMatrix.rawValue)
        XCTAssertFalse(store.restoresLastMatrix)
    }

    func testLastMatrixIsEmptyWhenNothingWasStored() {
        XCTAssertEqual(store.lastMatrix, "")
    }

    func testLastMatrixIsKeptAcrossStores() {
        store.lastMatrix = "zuzaz"

        XCTAssertEqual(UserDefaultsSettingsStore(defaults: defaults).lastMatrix, "zuzaz")
    }

    func testDefaultProgramUrlsReflectThePreferences() {
        defaults.set("https://example.com/v3.hex", forKey: SettingsKey.defaultProgramV3Url.rawValue)
        defaults.set("https://example.com/v1.hex", forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue)

        XCTAssertEqual(store.defaultProgramV3Url, "https://example.com/v3.hex")
        XCTAssertEqual(store.defaultProgramV1AndV2Url, "https://example.com/v1.hex")
    }

    func testDefaultProgramUrlsFallBackToTheBuiltInUrls() {
        XCTAssertEqual(store.defaultProgramV3Url, SettingsDefaults.defaultProgramV3Url)
        XCTAssertEqual(store.defaultProgramV1AndV2Url, SettingsDefaults.defaultProgramV1AndV2Url)
    }

    func testEditorUrlsReflectThePreferences() {
        defaults.set("https://makecode.example.com/", forKey: SettingsKey.makecodeUrl.rawValue)
        defaults.set("https://roberta.example.com/", forKey: SettingsKey.robertaUrl.rawValue)
        defaults.set("https://python.example.com/", forKey: SettingsKey.microPythonUrl.rawValue)

        XCTAssertEqual(store.makeCodeUrl, URL(string: "https://makecode.example.com/"))
        XCTAssertEqual(store.robertaUrl, URL(string: "https://roberta.example.com/"))
        XCTAssertEqual(store.microPythonUrl, URL(string: "https://python.example.com/"))
    }

    func testEditorUrlsFallBackToTheBuiltInUrls() {
        XCTAssertEqual(store.makeCodeUrl, URL(string: SettingsDefaults.makeCodeUrl))
        XCTAssertEqual(store.robertaUrl, URL(string: SettingsDefaults.robertaUrl))
        XCTAssertEqual(store.microPythonUrl, URL(string: SettingsDefaults.microPythonUrl))
    }

    func testNewsUrlReflectsThePreference() {
        defaults.set("https://example.com/news.json", forKey: SettingsKey.newsURL.rawValue)

        XCTAssertEqual(store.newsUrl, URL(string: "https://example.com/news.json"))
    }

    func testNewsUrlFallsBackToTheBuiltInUrl() {
        XCTAssertEqual(store.newsUrl, URL(string: SettingsDefaults.newsUrl))
    }
}
