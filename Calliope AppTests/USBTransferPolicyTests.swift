//
//  USBTransferPolicyTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

final class USBTransferPolicyTests: XCTestCase {

    func testPersonalIPadOnCurrentSystemUsesAFolder() {
        let policy = USBTransferPolicy(isSharedIPad: false, systemMajorVersion: 26)

        XCTAssertFalse(policy.picksDestinationPerFlash)
        XCTAssertFalse(policy.allowsUploadWithoutDevice)
    }

    func testOlderSystemPicksTheDestinationPerFlash() {
        let policy = USBTransferPolicy(isSharedIPad: false, systemMajorVersion: 18)

        XCTAssertTrue(policy.picksDestinationPerFlash)
        XCTAssertTrue(policy.allowsUploadWithoutDevice)
    }

    func testSharedIPadPicksTheDestinationPerFlashOnAnySystem() {
        let policy = USBTransferPolicy(isSharedIPad: true, systemMajorVersion: 26)

        XCTAssertTrue(policy.picksDestinationPerFlash)
        XCTAssertTrue(policy.allowsUploadWithoutDevice)
    }
}
