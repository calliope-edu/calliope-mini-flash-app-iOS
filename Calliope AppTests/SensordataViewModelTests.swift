//
//  SensordataViewModelTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

final class SensordataViewModelTests: XCTestCase {

    private var viewModel: SensordataViewModel!
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        viewModel = SensordataViewModel(connection: FakeDeviceConnection())
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    // MARK: - Tests

    func testDataloggerFileIsImportedWithItsContent() throws {
        let html = "<title>Calliope mini Datalog</title><script src=https://go.calliope.cc/assets/dl/3/dl.js></script>"
        let file = try makeFile("MY_DATA.HTM", content: html)

        let imported = try XCTUnwrap(viewModel.importDataLogger(from: .success(file)))

        XCTAssertEqual(try String(contentsOf: imported, encoding: .utf8), html)
        XCTAssertNil(viewModel.alert)
    }

    func testOtherHtmlFileIsRejectedWithAnAlert() throws {
        let file = try makeFile("page.html", content: "<html><body>Hello</body></html>")

        XCTAssertNil(viewModel.importDataLogger(from: .success(file)))
        XCTAssertEqual(viewModel.alert?.title, NSLocalizedString("Not a Datalogger File", comment: ""))
    }

    func testUnreadableFileShowsAnImportFailedAlert() {
        let missing = directory.appendingPathComponent("MY_DATA.HTM")

        XCTAssertNil(viewModel.importDataLogger(from: .success(missing)))
        XCTAssertEqual(viewModel.alert?.title, NSLocalizedString("Datalogger Import Failed!", comment: ""))
    }

    func testPickerFailureShowsAnImportFailedAlert() {
        XCTAssertNil(viewModel.importDataLogger(from: .failure(CocoaError(.fileReadNoPermission))))
        XCTAssertEqual(viewModel.alert?.title, NSLocalizedString("Datalogger Import Failed!", comment: ""))
    }

    // MARK: - Helpers

    private func makeFile(_ name: String, content: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
