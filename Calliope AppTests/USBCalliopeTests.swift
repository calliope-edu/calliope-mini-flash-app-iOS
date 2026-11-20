//
//  USBCalliopeTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import NordicDFU
import XCTest
@testable import Calliope_App

final class USBCalliopeTests: XCTestCase {

    private var directory: URL!
    private var hex: FakeHex!
    private let hexContent = Data(":00000001FF\n".utf8)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("My Program.hex")
        try hexContent.write(to: source)
        hex = FakeHex()
        hex.calliopeUSBUrl = source
    }

    override func tearDownWithError() throws {
        Calliope.isConnectionSwitching = false
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    // MARK: - Folder

    func testFolderUploadWritesTheHexIntoTheFolder() throws {
        let volume = try makeVolume()
        let calliope = USBCalliope(destination: .folder(volume))

        XCTAssertEqual(upload(to: calliope), [.completed])
        let written = try FileManager.default.contentsOfDirectory(at: volume, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "hex" }
        XCTAssertEqual(written.count, 1)
        XCTAssertEqual(try Data(contentsOf: written[0]), hexContent)
    }

    func testFolderUploadAbortsWhenTheVolumeIsGone() {
        let calliope = USBCalliope(destination: .folder(directory.appendingPathComponent("unplugged")))

        XCTAssertEqual(upload(to: calliope), [.aborted])
        XCTAssertFalse(calliope.lastExportCancelledByUser)
    }

    func testOnlyAFolderWithDetailsIsACalliopeVolume() throws {
        XCTAssertTrue(USBCalliope.isCalliopeVolume(try makeVolume()))
        XCTAssertFalse(USBCalliope.isCalliopeVolume(directory))
    }

    // MARK: - Picked per flash

    func testPickedUploadWritesTheHexIntoThePickedFile() throws {
        let placeholder = try makeVolume().appendingPathComponent("prog.hex")
        try Data().write(to: placeholder)
        let picker = FakeUSBDestinationPicker()
        picker.result = .success(placeholder)
        let calliope = USBCalliope(destination: .pickPerFlash(picker))

        XCTAssertEqual(upload(to: calliope), [.completed])
        XCTAssertEqual(try Data(contentsOf: placeholder), hexContent)
        XCTAssertEqual(picker.requestedFilenames.count, 1)
        XCTAssertTrue(picker.requestedFilenames[0].hasPrefix("my_p"))
    }

    func testCancelledPickerIsReportedAsCancelledByUser() {
        let picker = FakeUSBDestinationPicker()
        picker.result = nil
        let calliope = USBCalliope(destination: .pickPerFlash(picker))

        XCTAssertEqual(upload(to: calliope), [.aborted])
        XCTAssertTrue(calliope.lastExportCancelledByUser)
    }

    func testFailedPickerIsNotReportedAsCancelledByUser() {
        let picker = FakeUSBDestinationPicker()
        picker.result = .failure(CocoaError(.fileWriteNoPermission))
        let calliope = USBCalliope(destination: .pickPerFlash(picker))

        XCTAssertEqual(upload(to: calliope), [.aborted])
        XCTAssertFalse(calliope.lastExportCancelledByUser)
    }

    func testSecondUploadWhilePickerIsOpenIsIgnoredQuietly() throws {
        let picker = FakeUSBDestinationPicker()
        picker.staysOpen = true
        let pickerOpened = expectation(description: "picker opened")
        picker.onRequest = { pickerOpened.fulfill() }
        let calliope = USBCalliope(destination: .pickPerFlash(picker))
        let first = StatusRecorder()
        try calliope.upload(file: hex, statusDelegate: first)
        wait(for: [pickerOpened], timeout: 5)

        let second = StatusRecorder()
        try calliope.upload(file: hex, statusDelegate: second)

        XCTAssertEqual(second.states, [.aborted])
        XCTAssertTrue(calliope.lastExportCancelledByUser)
        XCTAssertEqual(picker.requestedFilenames.count, 1)
    }

    // MARK: - Helpers

    private func makeVolume() throws -> URL {
        let volume = directory.appendingPathComponent("MINI")
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        try Data("DAPLink".utf8).write(to: volume.appendingPathComponent("DETAILS.TXT"))
        return volume
    }

    private func upload(to calliope: USBCalliope) -> [DFUState] {
        let recorder = StatusRecorder()
        let finished = expectation(description: "upload finished")
        recorder.onState = { _ in finished.fulfill() }
        XCTAssertNoThrow(try calliope.upload(file: hex, statusDelegate: recorder))
        wait(for: [finished], timeout: 5)
        return recorder.states
    }
}

private final class StatusRecorder: NSObject, DFUServiceDelegate {
    private(set) var states: [DFUState] = []
    var onState: ((DFUState) -> Void)?

    func dfuStateDidChange(to state: DFUState) {
        states.append(state)
        onState?(state)
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {}
}
