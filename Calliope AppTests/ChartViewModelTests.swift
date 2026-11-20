//
//  ChartViewModelTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

final class ChartViewModelTests: XCTestCase {

    private var connection: FakeDeviceConnection!
    private var viewModel: ChartViewModel!

    override func setUp() {
        super.setUp()
        connection = FakeDeviceConnection()
        viewModel = ChartViewModel(
            chart: Chart(id: nil, sensorType: nil, groupsId: nil),
            connection: connection,
            documentStorage: FileDocumentStorage(),
            openFileNameDialog: { _ in },
            onNewLocation: { _, _ in },
            markLocation: { _, _ in },
            getMarkerColorForChart: { _ in .red }
        )
    }

    // MARK: - Tests

    func testCannotRecordWithoutSelectedSensor() {
        XCTAssertFalse(viewModel.canRecord)
    }

    func testCannotRecordSelectedSensorWithoutConnectedCalliope() {
        viewModel.selectSensor(selection: DropDownOption(name: accelerometer.name, object: accelerometer))

        XCTAssertFalse(viewModel.canRecord)
    }

    func testSelectedSensorIsKeptAfterDisconnect() {
        viewModel.selectSensor(selection: DropDownOption(name: accelerometer.name, object: accelerometer))

        NotificationCenter.default.post(name: DiscoveredBLEDevice.disconnectedNotificationName, object: nil)
        let handled = expectation(description: "disconnect handled")
        DispatchQueue.main.async { handled.fulfill() }
        wait(for: [handled], timeout: 1)

        XCTAssertEqual(viewModel.selectedSensor?.object.calliopeService, .accelerometer)
        XCTAssertFalse(viewModel.canRecord)
    }
}
