//
//  RobertaEditorTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

final class RobertaEditorTests: XCTestCase {

    private let editor = RobertaEditor(url: URL(string: "https://roberta.example.com/ios/"))

    func testPagesOfTheConfiguredEditorOpenInternally() {
        let request = URLRequest(url: URL(string: "https://roberta.example.com/ios/program")!)

        XCTAssertEqual(editor.getNavigationTargetViewForRequest(request), .internalWebView)
    }

    func testOtherPagesOpenExternally() {
        let request = URLRequest(url: URL(string: "https://lab.open-roberta.org/")!)

        XCTAssertEqual(editor.getNavigationTargetViewForRequest(request), .externalWebView)
    }
}
