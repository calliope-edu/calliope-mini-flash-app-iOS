//
//  DeviceConnectionServiceTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import CoreBluetooth
import XCTest
@testable import Calliope_App

final class DeviceConnectionServiceTests: XCTestCase {

    private let nameA = Matrix.heights2friendly([1, 2, 3, 4, 5])!
    private let nameB = Matrix.heights2friendly([5, 4, 3, 2, 1])!
    private let folderPolicy = USBTransferPolicy(isSharedIPad: false, systemMajorVersion: 26)
    private let pickPerFlashPolicy = USBTransferPolicy(isSharedIPad: false, systemMajorVersion: 18)

    private var savedDefaults: [String: Any] = [:]
    private var discoveries: [FakeDiscovery] = []
    private var viewModel: MatrixConnectionViewModel!
    private var service: CalliopeConnectionService!
    private var picker: FakeUSBDestinationPicker!
    private var subscriptions: Set<AnyCancellable> = []

    private var discovery: FakeDiscovery {
        discoveries.last!
    }

    override func setUp() {
        super.setUp()
        for key in [SettingsKey.restoreLastMatrix.rawValue, SettingsKey.lastMatrix.rawValue] {
            savedDefaults[key] = UserDefaults.standard.object(forKey: key)
        }
        UserDefaults.standard.set(false, forKey: SettingsKey.restoreLastMatrix.rawValue)

        makeService(usbPolicy: folderPolicy)
    }

    override func tearDown() {
        subscriptions = []
        Calliope.isConnectionSwitching = false
        for (key, value) in savedDefaults {
            UserDefaults.standard.set(value, forKey: key)
        }
        super.tearDown()
    }

    // MARK: - Lifecycle

    func testStartReplacesTheInitialDiscovery() {
        XCTAssertEqual(discoveries.count, 2)
        XCTAssertTrue(discoveries[0].gaveUpResponsibility)
        XCTAssertTrue(discoveries[1].context === service)
    }

    func testBackgroundStopsAndForegroundRestartsDiscovery() {
        let starts = discovery.startDiscoveryCount
        let stops = discovery.stopDiscoveryCount

        service.enterBackground()
        XCTAssertTrue(discovery.isInBackground)
        XCTAssertEqual(discovery.stopDiscoveryCount, stops + 1)

        service.enterForeground()
        XCTAssertFalse(discovery.isInBackground)
        XCTAssertEqual(discovery.startDiscoveryCount, starts + 1)
    }

    func testSuspendedBluetoothIgnoresDevicesUntilResumed() {
        select(nameA)
        let device = FakeDiscoveredDevice(name: nameA)

        service.suspendBluetooth()
        discovery.discover(device)
        XCTAssertTrue(discovery.connectRequests.isEmpty)

        service.resumeBluetooth()
        XCTAssertFalse(discovery.isInBackground)
        XCTAssertEqual(discovery.connectRequests, [device])
    }

    // MARK: - Connecting by matrix

    func testDeviceMatchingTheSelectedMatrixIsConnected() {
        select(nameA)
        let device = FakeDiscoveredDevice(name: nameA)

        discovery.discover(device)

        XCTAssertEqual(discovery.connectRequests, [device])
    }

    func testDeviceWithAnotherNameIsNotConnected() {
        select(nameA)

        discovery.discover(FakeDiscoveredDevice(name: nameB))
        discovery.setState(.discoveredAll)

        XCTAssertTrue(discovery.connectRequests.isEmpty)
        XCTAssertEqual(viewModel.connectButtonState, .notFoundRetry)
    }

    func testUsageReadyDeviceBecomesCurrentAndItsMatrixIsRemembered() {
        select(nameA)
        let calliope = FakeCalliope()
        let device = usageReadyDevice(named: nameA, calliope: calliope)

        discovery.connectBLE(device)

        XCTAssertTrue(service.currentCalliope === calliope)
        XCTAssertTrue(service.bleCalliope === calliope)
        XCTAssertEqual(UserDefaults.standard.string(forKey: SettingsKey.lastMatrix.rawValue), service.matrixString)
        XCTAssertEqual(viewModel.connectionMenuButtonState, .connected)
    }

    func testAutoReconnectToAnotherDeviceAdoptsItsMatrix() {
        select(nameA)

        discovery.connectBLE(usageReadyDevice(named: nameB, calliope: FakeCalliope()))

        XCTAssertEqual(Matrix.matrix2friendly(viewModel.matrix), nameB)
    }

    // MARK: - USB

    func testUsbModeUsesTheUsbDevice() {
        viewModel.isInUsbMode = true
        let calliope = FakeUSBCalliope()
        let device = DiscoveredUSBDevice(name: "USB_CALLIOPE", destination: .pickPerFlash(picker))
        device.usageReadyCalliope = calliope

        discovery.connectUSB(device)

        XCTAssertTrue(service.isUsbMode)
        XCTAssertTrue(service.isUsbConnected)
        XCTAssertTrue(service.currentCalliope === calliope)
    }

    func testConnectingUsbWithAFolderOpensTheFolderPicker() {
        viewModel.isInUsbMode = true
        viewModel.startUsbConnect()

        XCTAssertTrue(viewModel.isFolderPickerPresented)
        XCTAssertNil(viewModel.alert)
    }

    func testPickedFolderBecomesTheUsbDestination() {
        let folder = URL(fileURLWithPath: "/Volumes/MINI")

        viewModel.handleUSBFolderPicked(folder)

        guard case .folder(let url) = discovery.usbDestinations.last else {
            return XCTFail("Expected a folder destination")
        }
        XCTAssertEqual(url, folder)
    }

    func testContinuingTheHeadsUpConnectsWithTheInjectedPicker() {
        makeService(usbPolicy: pickPerFlashPolicy)
        viewModel.startUsbConnect()

        viewModel.alert?.actions.first?.handler()

        guard case .pickPerFlash(let usedPicker) = discovery.usbDestinations.last else {
            return XCTFail("Expected a pick-per-flash destination")
        }
        XCTAssertTrue(usedPicker === picker)
    }

    func testSwitchingUsbOnShowsTheHeadsUpWhenTheDestinationIsPickedPerFlash() {
        makeService(usbPolicy: pickPerFlashPolicy)

        viewModel.isInUsbMode = true
        drainMainQueue()

        XCTAssertEqual(viewModel.alert?.title, AppAlert.usbExportPickerNotice(isSharedIPad: false) {}.title)
        XCTAssertFalse(viewModel.isFolderPickerPresented)
    }

    // MARK: - DFU

    func testDfuModeKeepsDiscoveryFromConnecting() {
        select(nameA)
        service.setDfuMode(true)

        discovery.discover(FakeDiscoveredDevice(name: nameA))

        XCTAssertTrue(discovery.connectRequests.isEmpty)
    }

    func testDfuModeShowsTransmittingWhileConnecting() {
        discovery.setState(.connecting)
        XCTAssertEqual(viewModel.connectionMenuButtonState, .connecting)

        service.setDfuMode(true)
        discovery.setState(.connecting)
        XCTAssertEqual(viewModel.connectionMenuButtonState, .transmitting)
    }

    // MARK: - Reconnect

    func testReconnectPrefersTheNamedDevice() {
        let deviceB = FakeDiscoveredDevice(name: nameB)
        discovery.discover(FakeDiscoveredDevice(name: nameA), deviceB, state: .discoveredAll)

        service.reconnect(preferredName: nameB)

        XCTAssertEqual(discovery.connectRequests, [deviceB])
    }

    func testReconnectFallsBackToTheOnlyVisibleDevice() {
        let device = FakeDiscoveredDevice(name: nameA)
        discovery.discover(device, state: .discoveredAll)

        service.reconnect(preferredName: nameB)

        XCTAssertEqual(discovery.connectRequests, [device])
    }

    func testReconnectDoesNothingWhenAmbiguousOrAlreadyConnecting() {
        discovery.discover(FakeDiscoveredDevice(name: nameA), FakeDiscoveredDevice(name: nameB), state: .discoveredAll)
        service.reconnect(preferredName: nil)

        discovery.setState(.connecting)
        service.reconnect(preferredName: nameA)

        XCTAssertTrue(discovery.connectRequests.isEmpty)
    }

    // MARK: - Connection events

    func testRemovedPairingReportsConnectionLost() {
        let lost = expectation(description: "connection lost")
        service.connectionLost.sink { lost.fulfill() }.store(in: &subscriptions)

        discovery.errorBlock(CBError(.peerRemovedPairingInformation))

        wait(for: [lost], timeout: 1)
    }

    func testDisconnectsArePassedOn() {
        var disconnected: [String] = []
        service.deviceDisconnected.sink { disconnected.append($0) }.store(in: &subscriptions)

        discovery.reportDisconnect(uuid: "1234")

        XCTAssertEqual(disconnected, ["1234"])
    }

    // MARK: - Helpers

    private func makeService(usbPolicy: USBTransferPolicy) {
        discoveries = []
        picker = FakeUSBDestinationPicker()
        service = CalliopeConnectionService(usbPolicy: usbPolicy, usbDestinationPicker: picker, makeDiscovery: { [unowned self] _, context in
            let discovery = FakeDiscovery(context: context)
            discoveries.append(discovery)
            return discovery
        })
        viewModel = MatrixConnectionViewModel(connection: service, usbPolicy: usbPolicy)
        service.start()
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }

    private func select(_ name: String) {
        viewModel.matrix = Matrix.friendly2Matrix(name)
    }

    private func usageReadyDevice(named name: String, calliope: Calliope) -> FakeDiscoveredDevice {
        let device = FakeDiscoveredDevice(name: name)
        device.usageReadyCalliope = calliope
        device.state = .usageReady
        return device
    }
}
