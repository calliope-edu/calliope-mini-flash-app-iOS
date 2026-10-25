//
//  FlashServiceTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

@MainActor
final class FlashServiceTests: XCTestCase {

    private var connection: FakeDeviceConnection!
    private var device: FakeCalliope!
    private var service: FlashService!
    private var events: [String] = []

    override func setUp() {
        super.setUp()
        Calliope.isConnectionSwitching = false
        connection = FakeDeviceConnection()
        device = FakeCalliope()
        connection.currentCalliope = device
        service = FlashService(connection: connection)
        events = []
    }

    override func tearDown() {
        Calliope.isConnectionSwitching = false
        super.tearDown()
    }

    // MARK: - Tests

    func testSuccessfulFlashReportsProgressThenCompletion() {
        flash()
        device.reportProgress(50)
        device.reportState(.completed)

        XCTAssertEqual(receivedEvents(), ["progress(0.0)", "progress(0.5)", "completed"])
    }

    func testIncompatibleHexIsRejectedBeforeTouchingTheDevice() {
        flash(FakeHex(hexTypes: [.v2]))

        XCTAssertEqual(receivedEvents(), ["failed(incompatibleHex)"])
        XCTAssertEqual(device.cancelCount, 0)
    }

    func testCancelIgnoresTheDevicesLateAbort() {
        flash()
        service.cancel()
        device.reportState(.aborted)

        XCTAssertEqual(receivedEvents(), ["progress(0.0)", "cancelled"])
        XCTAssertEqual(device.cancelCount, 1)
    }

    func testNewFlashSilencesThePreviousOne() {
        var firstEvents: [String] = []
        service.flash(FakeHex()) { firstEvents.append($0.label) }
        let firstDevice = device!

        let secondDevice = FakeCalliope()
        connection.currentCalliope = secondDevice
        flash()
        firstDevice.reportProgress(80)
        firstDevice.reportState(.completed)
        secondDevice.reportState(.completed)

        XCTAssertEqual(receivedEvents(), ["progress(0.0)", "completed"])
        XCTAssertEqual(firstEvents, ["progress(0.0)"])
        XCTAssertEqual(firstDevice.cancelCount, 1)
    }

    func testConnectionLossEndsTheFlash() {
        flash()
        connection.loseConnection()
        device.reportState(.completed)

        XCTAssertEqual(receivedEvents(), ["progress(0.0)", "failed(connectionLost)"])
    }

    func testAbortDuringConnectionSwitchIsSuppressed() {
        flash()
        Calliope.isConnectionSwitching = true
        device.reportState(.aborted)

        XCTAssertEqual(receivedEvents(), ["progress(0.0)"])
    }

    func testDfuErrorIsReportedOnce() {
        flash()
        device.reportError("Device disconnected")
        device.reportState(.aborted)

        XCTAssertEqual(receivedEvents(), ["progress(0.0)", "failed(dfu)"])
    }

    func testUSBRejectionAfterCompletionIsStillReported() {
        let usbDevice = FakeUSBCalliope()
        connection.currentCalliope = usbDevice
        flash()
        usbDevice.reportState(.completed)
        usbDevice.reportRejection("The hex file cannot be decoded.")

        XCTAssertEqual(receivedEvents(), ["progress(nil)", "completed", "failed(transferRejected)"])
    }

    // MARK: - Private Helpers

    private func flash(_ hex: Hex = FakeHex()) {
        service.flash(hex) { [unowned self] event in
            self.events.append(event.label)
        }
    }

    // Events are delivered asynchronously on the main queue.
    private func receivedEvents() -> [String] {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
        return events
    }
}

private extension UploadEvent {
    var label: String {
        switch self {
        case .progress(let value):
            return "progress(\(value.map { String($0) } ?? "nil"))"
        case .completed:
            return "completed"
        case .cancelled:
            return "cancelled"
        case .failed(let error):
            return "failed(\(error.label))"
        }
    }
}

private extension UploadError {
    var label: String {
        switch self {
        case .notConnected: return "notConnected"
        case .incompatibleHex: return "incompatibleHex"
        case .connectionLost: return "connectionLost"
        case .dfu: return "dfu"
        case .transferRejected: return "transferRejected"
        }
    }
}
