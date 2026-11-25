//
//  CalliopeDiscoveryTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import CoreBluetooth
import XCTest
@testable import Calliope_App

final class CalliopeDiscoveryTests: XCTestCase {

    private var central: FakeCentralManager!
    private var context: FakeDiscoveryContext!
    private var discovery: CalliopeDiscovery!

    override func setUp() {
        super.setUp()
        central = FakeCentralManager()
        context = FakeDiscoveryContext()
        discovery = CalliopeDiscovery(
            { _, _ in fatalError("these tests discover no Bluetooth devices") },
            context: context,
            makeCentralManager: { [central] _ in central! }
        )
    }

    // MARK: - Bluetooth state

    func testBluetoothTurningOnStartsScanning() {
        central.state = .poweredOn
        discovery.bluetoothStateDidChange()

        XCTAssertEqual(central.scanCount, 1)
        XCTAssertEqual(discovery.state, .discovering)
    }

    func testBluetoothStateIsPassedOn() {
        let passedOn = expectation(description: "Bluetooth state passed on")
        discovery.bluetoothStateChangedBlock = { state in
            XCTAssertEqual(state, .unauthorized)
            passedOn.fulfill()
        }

        central.state = .unauthorized
        discovery.bluetoothStateDidChange()

        wait(for: [passedOn], timeout: 1)
    }

    func testBluetoothTurningOffResetsTheDiscovery() {
        central.state = .poweredOn
        discovery.bluetoothStateDidChange()

        central.state = .poweredOff
        discovery.bluetoothStateDidChange()

        XCTAssertEqual(discovery.state, .initialized)
        XCTAssertTrue(discovery.discoveredCalliopes.isEmpty)
    }

    func testBluetoothTurningOffKeepsTheUsbConnection() {
        discovery.connectUsbCalliope(to: .pickPerFlash(FakeUSBDestinationPicker()))

        central.state = .poweredOff
        discovery.bluetoothStateDidChange()

        XCTAssertEqual(discovery.state, .usbConnected)
        XCTAssertNotNil(discovery.connectedUSBDevice)
    }

    // MARK: - Scanning

    func testStoppingTheDiscoveryStopsScanning() {
        central.state = .poweredOn
        discovery.startCalliopeDiscovery()

        discovery.stopCalliopeDiscovery()

        XCTAssertEqual(central.stopScanCount, 1)
        XCTAssertEqual(discovery.state, .initialized)
    }

    func testStartingTwiceScansOnce() {
        central.state = .poweredOn

        discovery.startCalliopeDiscovery()
        discovery.startCalliopeDiscovery()

        XCTAssertEqual(central.scanCount, 1)
    }

    // MARK: - USB

    func testStartingUsbConnectShowsConnecting() {
        discovery.startUsbConnect()

        XCTAssertEqual(discovery.state, .usbConnecting)
    }

    func testPickPerFlashDestinationConnectsAUsbCalliope() {
        discovery.connectUsbCalliope(to: .pickPerFlash(FakeUSBDestinationPicker()))

        XCTAssertEqual(discovery.state, .usbConnected)
        XCTAssertTrue(discovery.connectedUSBDevice?.usageReadyCalliope is USBCalliope)
    }

    func testFolderThatIsNoCalliopeIsRejected() {
        let folder = FileManager.default.temporaryDirectory

        discovery.connectUsbCalliope(to: .folder(folder))

        XCTAssertEqual(context.invalidUsbLocationReports, 1)
        XCTAssertEqual(discovery.state, .initialized)
        XCTAssertNil(discovery.connectedUSBDevice)
    }

    func testDisconnectingRemovesTheUsbCalliope() {
        discovery.connectUsbCalliope(to: .pickPerFlash(FakeUSBDestinationPicker()))

        discovery.disconnectFromCalliope()

        XCTAssertNil(discovery.connectedUSBDevice)
        XCTAssertTrue(discovery.discoveredCalliopes.isEmpty)
        XCTAssertEqual(discovery.state, .initialized)
    }
}

private final class FakeDiscoveryContext: CalliopeDiscoveryContext {
    var isUsbMode = false
    var isConnectionEnabled = false
    private(set) var invalidUsbLocationReports = 0

    func reportInvalidUsbLocation() {
        invalidUsbLocationReports += 1
    }
}
