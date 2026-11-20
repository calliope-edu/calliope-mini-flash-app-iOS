//
//  CampusRouteTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

final class CampusRouteTests: XCTestCase {

    func testEmptyPathIsTheCampusHome() {
        XCTAssertEqual(CampusRoute.url(path: "", on: URL(string: "https://campus.example.com")), URL(string: "https://campus.example.com"))
    }

    func testPathIsAppendedToTheOrigin() {
        XCTAssertEqual(CampusRoute.url(path: "/makecode/", on: URL(string: "https://campus.example.com")), URL(string: "https://campus.example.com/makecode"))
    }

    func testPathQueryAndFragmentOfTheConfiguredUrlAreDropped() {
        let configured = URL(string: "https://campus.example.com/blocks?mobile=true#top")

        XCTAssertEqual(CampusRoute.url(path: "blocks", on: configured), URL(string: "https://campus.example.com/blocks"))
    }

    func testUrlWithoutHostGivesNoRoute() {
        XCTAssertNil(CampusRoute.url(path: "blocks", on: URL(string: "campus")))
        XCTAssertNil(CampusRoute.url(path: "blocks", on: nil))
    }
}
