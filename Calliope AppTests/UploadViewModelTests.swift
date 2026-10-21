//
//  UploadViewModelTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import XCTest
@testable import Calliope_App

@MainActor
final class UploadViewModelTests: XCTestCase {

    private var connection: FakeDeviceConnection!

    override func setUp() {
        super.setUp()
        connection = FakeDeviceConnection()
    }

    // MARK: - Tests

    func testUsbUploadWithoutDeviceAsksForConfirmationWhenTheDestinationIsPickedPerFlash() {
        connection.isUsbMode = true
        let viewModel = makeViewModel(usbPolicy: USBTransferPolicy(isSharedIPad: false, systemMajorVersion: 18))

        viewModel.upload(FakeHex())

        XCTAssertEqual(viewModel.alert?.title, AppAlert.uploadConfirmation(name: nil) {}.title)
    }

    func testUsbUploadWithoutDeviceIsRefusedWithAFolder() {
        connection.isUsbMode = true
        let viewModel = makeViewModel(usbPolicy: USBTransferPolicy(isSharedIPad: false, systemMajorVersion: 26))

        viewModel.upload(FakeHex())

        XCTAssertEqual(viewModel.alert?.title, AppAlert.cannotUpload().title)
    }

    func testBluetoothUploadWithoutDeviceIsRefused() {
        let viewModel = makeViewModel(usbPolicy: USBTransferPolicy(isSharedIPad: true, systemMajorVersion: 26))

        viewModel.upload(FakeHex())

        XCTAssertEqual(viewModel.alert?.title, AppAlert.cannotUpload().title)
    }

    // MARK: - Helpers

    private func makeViewModel(usbPolicy: USBTransferPolicy) -> UploadViewModel {
        UploadViewModel(
            flashService: FlashService(connection: connection),
            connection: connection,
            connectionPanel: MatrixConnectionViewModel(connection: PreviewDeviceConnectionService(), usbPolicy: usbPolicy),
            usbPolicy: usbPolicy
        )
    }
}
