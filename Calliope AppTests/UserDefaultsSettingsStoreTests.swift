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
}
