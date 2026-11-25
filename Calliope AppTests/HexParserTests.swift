//
//  HexParserTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

final class HexParserTests: XCTestCase {

    private let dataRecord = ":10010000214601360121470136007EFE09D2190140"
    private let endOfFile = ":00000001FF"

    private var folder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
        try super.tearDownWithError()
    }

    func testMakeCodeHexForMini1And2IsV2() throws {
        XCTAssertEqual(HexParser(url: try fixture("makecode_v12")).getHexVersion(), [.v2])
    }

    func testMakeCodeHexForMini3IsV3() throws {
        XCTAssertEqual(HexParser(url: try fixture("makecode_v3")).getHexVersion(), [.v3])
    }

    func testOpenRobertaHexForMini1And2IsV2() throws {
        XCTAssertEqual(HexParser(url: try fixture("nepo_v12")).getHexVersion(), [.v2])
    }

    func testOpenRobertaHexForMini3IsV3() throws {
        XCTAssertEqual(HexParser(url: try fixture("nepo_v3")).getHexVersion(), [.v3])
    }

    func testArcadeHexIsV3() throws {
        XCTAssertEqual(HexParser(url: try fixture("arcade")).getHexVersion(), [.v3])
    }
    
    func testMicrosoftArcadeHexIsArcade() throws {
        XCTAssertEqual(HexParser(url: try fixture("microsoft_arcade")).getHexVersion(), [.arcade])
    }
    
    func testMicroPythonHexIsUniversal() throws {
        XCTAssertEqual(HexParser(url: try fixture("micropython")).getHexVersion(), [.v2, .universal])
    }

    func testCalliopeBlocksHexIsUniversal() throws {
        XCTAssertEqual(HexParser(url: try fixture("blocks")).getHexVersion(), [.v2, .universal])
    }

    func testDetectsV3ShieldMarker() throws {
        let url = try writeHex([HexParser.HexVersion.v3Shield.rawValue, dataRecord, endOfFile])

        XCTAssertEqual(HexParser(url: url).getHexVersion(), [.v3Shield])
    }

    func testIgnoresWindowsLineEndingsAndSurroundingWhitespace() throws {
        let url = folder.appendingPathComponent("crlf.hex")
        try Data("  \(HexParser.HexVersion.v3.rawValue)  \r\n\(dataRecord)\r\n\(endOfFile)\r\n".utf8).write(to: url)

        XCTAssertEqual(HexParser(url: url).getHexVersion(), [.v3])
    }

    func testUnknownHexIsInvalid() throws {
        let url = try writeHex([dataRecord, dataRecord, endOfFile])

        XCTAssertEqual(HexParser(url: url).getHexVersion(), [.invalid])
    }

    func testNonHexFileIsInvalid() throws {
        let url = try writeHex(["<html>", "<body>not a hex</body>", "</html>"])

        XCTAssertEqual(HexParser(url: url).getHexVersion(), [.invalid])
    }

    func testEmptyFileIsInvalid() throws {
        let url = try writeHex([])

        XCTAssertEqual(HexParser(url: url).getHexVersion(), [.invalid])
    }

    func testMissingFileIsInvalid() {
        let url = folder.appendingPathComponent("missing.hex")

        XCTAssertEqual(HexParser(url: url).getHexVersion(), [.invalid])
    }

    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle(for: HexParserTests.self).url(forResource: name, withExtension: "hex"))
    }

    private func writeHex(_ lines: [String]) throws -> URL {
        let url = folder.appendingPathComponent("\(UUID().uuidString).hex")
        try Data(lines.map { $0 + "\n" }.joined().utf8).write(to: url)
        return url
    }
}
