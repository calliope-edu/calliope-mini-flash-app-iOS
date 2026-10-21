//
//  UploadViewModelTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import XCTest
@testable import Calliope_App

@MainActor
final class UploadViewModelTests: XCTestCase {

    private var connection: FakeDeviceConnection!

    override func setUp() {
        super.setUp()
        Calliope.isConnectionSwitching = false
        connection = FakeDeviceConnection()
    }

    override func tearDown() {
        Calliope.isConnectionSwitching = false
        super.tearDown()
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

    func testCompletedFlashShowsSuccessBeforeHidingThePanel() {
        let device = connectDevice()
        let viewModel = makeViewModel(resultDisplayDuration: 60)

        viewModel.uploadWithoutConfirmation(FakeHex())
        drainMainQueue()
        device.reportState(.completed)
        drainMainQueue()

        XCTAssertTrue(viewModel.isUploading)
        XCTAssertEqual(viewModel.transferResult, .succeeded)
    }

    func testResultIsHiddenAfterTheDisplayDuration() {
        let device = connectDevice()
        let viewModel = makeViewModel(resultDisplayDuration: 0)

        viewModel.uploadWithoutConfirmation(FakeHex())
        drainMainQueue()
        device.reportState(.completed)

        let hidden = expectation(description: "panel hidden")
        let subscription = viewModel.$isUploading.dropFirst().filter { !$0 }.sink { _ in hidden.fulfill() }
        wait(for: [hidden], timeout: 1)
        subscription.cancel()

        XCTAssertNil(viewModel.transferResult)
    }

    func testCancelShowsFailureAndCancelsTheFlash() {
        let device = connectDevice()
        let viewModel = makeViewModel(resultDisplayDuration: 60)

        viewModel.uploadWithoutConfirmation(FakeHex())
        drainMainQueue()
        viewModel.cancel()
        drainMainQueue()

        XCTAssertTrue(viewModel.isUploading)
        XCTAssertEqual(viewModel.transferResult, .failed)
        XCTAssertEqual(device.cancelCount, 1)
    }

    func testFailureAlertIsPresentedOnlyAfterTheResult() {
        let device = connectDevice()
        let viewModel = makeViewModel(resultDisplayDuration: 60)

        viewModel.uploadWithoutConfirmation(FakeHex())
        drainMainQueue()
        device.reportError("Device disconnected")
        drainMainQueue()

        XCTAssertEqual(viewModel.transferResult, .failed)
        XCTAssertNil(viewModel.alert)

        viewModel.finishProgress()

        XCTAssertNotNil(viewModel.alert)
    }

    func testLateUSBRejectionTurnsTheShownSuccessIntoFailure() {
        let device = FakeUSBCalliope()
        connection.currentCalliope = device
        let viewModel = makeViewModel(resultDisplayDuration: 60)

        viewModel.uploadWithoutConfirmation(FakeHex())
        drainMainQueue()
        device.reportState(.completed)
        drainMainQueue()
        device.reportRejection("The hex file cannot be decoded.")
        drainMainQueue()

        XCTAssertEqual(viewModel.transferResult, .failed)
    }

    func testNewTransferReplacesTheShownResult() {
        let device = connectDevice()
        let viewModel = makeViewModel(resultDisplayDuration: 60)

        viewModel.uploadWithoutConfirmation(FakeHex())
        drainMainQueue()
        device.reportState(.completed)
        drainMainQueue()
        viewModel.startProgress()

        XCTAssertTrue(viewModel.isUploading)
        XCTAssertNil(viewModel.transferResult)
    }

    // MARK: - Helpers

    private func makeViewModel(
        usbPolicy: USBTransferPolicy = USBTransferPolicy(isSharedIPad: false, systemMajorVersion: 26),
        resultDisplayDuration: TimeInterval = 0
    ) -> UploadViewModel {
        UploadViewModel(
            flashService: FlashService(connection: connection),
            connection: connection,
            connectionPanel: MatrixConnectionViewModel(connection: PreviewDeviceConnectionService(), usbPolicy: usbPolicy),
            usbPolicy: usbPolicy,
            resultDisplayDuration: resultDisplayDuration
        )
    }

    private func connectDevice() -> FakeCalliope {
        let device = FakeCalliope()
        connection.currentCalliope = device
        return device
    }

    // Flash events are delivered asynchronously on the main queue.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}
