//
//  FileDocumentStorageTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

final class FileDocumentStorageTests: XCTestCase {

    private var folder: URL!
    private var outside: URL!
    private var storage: FileDocumentStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        folder = root.appendingPathComponent("Documents")
        outside = root.appendingPathComponent("Downloads")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        storage = FileDocumentStorage(resolveDirectory: { [folder] in folder! })
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder.deletingLastPathComponent())
        try super.tearDownWithError()
    }

    func testSaveWritesTheFileIntoTheFolder() throws {
        let url = try storage.save(Data("a,b".utf8), as: "export.csv", atomically: true)

        XCTAssertEqual(url, folder.appendingPathComponent("export.csv"))
        XCTAssertEqual(try Data(contentsOf: url), Data("a,b".utf8))
    }

    func testSaveReplacesAnExistingFile() throws {
        try storage.save(Data("old".utf8), as: "export.csv", atomically: false)

        let url = try storage.save(Data("new".utf8), as: "export.csv", atomically: false)

        XCTAssertEqual(try Data(contentsOf: url), Data("new".utf8))
    }

    func testSaveFailsWhenTheFolderCannotBeResolved() {
        let storage = FileDocumentStorage(resolveDirectory: { throw CocoaError(.fileNoSuchFile) })

        XCTAssertThrowsError(try storage.save(Data(), as: "export.csv", atomically: true))
    }

    func testMoveInMovesTheFileIntoTheFolder() throws {
        let source = outside.appendingPathComponent("session.json")
        try Data("{}".utf8).write(to: source)

        let url = try storage.moveIn(source)

        XCTAssertEqual(url, folder.appendingPathComponent("session.json"))
        XCTAssertEqual(try Data(contentsOf: url), Data("{}".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testMoveInFailsWhenTheFileAlreadyExists() throws {
        try storage.save(Data("kept".utf8), as: "session.json", atomically: true)
        let source = outside.appendingPathComponent("session.json")
        try Data("{}".utf8).write(to: source)

        XCTAssertThrowsError(try storage.moveIn(source))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("session.json")), Data("kept".utf8))
    }

    func testFileExistsReportsSavedFilesOnly() throws {
        try storage.save(Data(), as: "program.hex", atomically: false)

        XCTAssertTrue(try storage.fileExists(named: "program.hex"))
        XCTAssertFalse(try storage.fileExists(named: "other.hex"))
    }

    func testFilesListsOnlyTheRequestedExtensionsIgnoringCase() throws {
        try storage.save(Data(), as: "a.hex", atomically: false)
        try storage.save(Data(), as: "b.PY", atomically: false)
        try storage.save(Data(), as: "c.csv", atomically: false)

        let names = try storage.files(withExtensions: ["hex", "py"]).map(\.lastPathComponent).sorted()

        XCTAssertEqual(names, ["a.hex", "b.PY"])
    }

    func testRenameMovesTheFileToTheNewName() throws {
        let file = try storage.save(Data("print()".utf8), as: "old.py", atomically: false)

        let renamed = try storage.rename(file, to: "new.py")

        XCTAssertEqual(renamed, folder.appendingPathComponent("new.py"))
        XCTAssertEqual(try Data(contentsOf: renamed), Data("print()".utf8))
        XCTAssertFalse(try storage.fileExists(named: "old.py"))
    }

    func testRenameFailsWhenTheNewNameIsTaken() throws {
        let file = try storage.save(Data("a".utf8), as: "a.hex", atomically: false)
        try storage.save(Data("b".utf8), as: "b.hex", atomically: false)

        XCTAssertThrowsError(try storage.rename(file, to: "b.hex"))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("b.hex")), Data("b".utf8))
    }

    func testDeleteRemovesTheFile() throws {
        let file = try storage.save(Data(), as: "program.hex", atomically: false)

        try storage.delete(file)

        XCTAssertFalse(try storage.fileExists(named: "program.hex"))
    }
}
