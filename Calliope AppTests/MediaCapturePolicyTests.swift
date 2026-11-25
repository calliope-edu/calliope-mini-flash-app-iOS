//
//  MediaCapturePolicyTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import WebKit
import XCTest
@testable import Calliope_App

final class MediaCapturePolicyTests: XCTestCase {

    func testTrustedHostOverHttpsIsGranted() {
        XCTAssertEqual(MediaCapturePolicy.decision(scheme: "https", host: "campus.calliope.cc"), .grant)
    }

    func testTeachableMachineOverHttpsIsGranted() {
        XCTAssertEqual(MediaCapturePolicy.decision(scheme: "https", host: "teachablemachine.calliope.cc"), .grant)
    }

    func testGoCalliopeOverHttpsIsGranted() {
        XCTAssertEqual(MediaCapturePolicy.decision(scheme: "https", host: "go.calliope.cc"), .grant)
    }

    func testHostIsComparedCaseInsensitively() {
        XCTAssertEqual(MediaCapturePolicy.decision(scheme: "https", host: "Campus.Calliope.cc"), .grant)
    }

    func testUnknownHostOverHttpsIsPrompted() {
        XCTAssertEqual(MediaCapturePolicy.decision(scheme: "https", host: "example.com"), .prompt)
    }

    func testLookalikeHostIsPrompted() {
        XCTAssertEqual(MediaCapturePolicy.decision(scheme: "https", host: "campus.calliope.cc.example.com"), .prompt)
    }

    func testTrustedHostWithoutHttpsIsDenied() {
        XCTAssertEqual(MediaCapturePolicy.decision(scheme: "http", host: "campus.calliope.cc"), .deny)
    }
}
