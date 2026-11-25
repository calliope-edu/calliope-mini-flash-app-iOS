//
//  EditorsAndProgramsViewModelTests.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import XCTest
@testable import Calliope_App

@MainActor
final class EditorsAndProgramsViewModelTests: XCTestCase {

    private var settings: FakeSettingsStore!
    private var notificationCenter: NotificationCenter!

    override func setUp() {
        super.setUp()
        settings = FakeSettingsStore()
        notificationCenter = NotificationCenter()
    }

    // MARK: - Tests

    func testAllEditorsAreShownWhenEnabled() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.editors.map(\.name), ["Calliope mini Blocks", "MakeCode", "Scan", "Micropython", "Arcade", "Open Roberta Lab"])
    }

    func testDisabledMakeCodeHidesMakeCodeAndScan() {
        settings.isMakeCodeEnabled = false

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.editors.map(\.name), ["Calliope mini Blocks", "Micropython", "Arcade", "Open Roberta Lab"])
    }

    func testDisabledArcadeAndRobertaAreHidden() {
        settings.isArcadeEnabled = false
        settings.isRobertaEnabled = false

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.editors.map(\.name), ["Calliope mini Blocks", "MakeCode", "Scan", "Micropython"])
    }

    func testChangedSettingsUpdateTheEditors() {
        let viewModel = makeViewModel()
        let updated = expectation(description: "editors updated")
        let observer = viewModel.$editors.dropFirst().sink { editors in
            XCTAssertFalse(editors.map(\.name).contains("Arcade"))
            updated.fulfill()
        }

        settings.isArcadeEnabled = false
        notificationCenter.post(name: UserDefaults.didChangeNotification, object: nil)

        wait(for: [updated], timeout: 1)
        observer.cancel()
    }

    // MARK: - Helpers

    private func makeViewModel() -> EditorsAndProgramsViewModel {
        let connection = FakeDeviceConnection()
        let usbPolicy = USBTransferPolicy(isSharedIPad: false, systemMajorVersion: 26)
        let uploadViewModel = UploadViewModel(
            flashService: FlashService(connection: connection),
            connection: connection,
            connectionPanel: MatrixConnectionViewModel(connection: PreviewDeviceConnectionService(), usbPolicy: usbPolicy),
            usbPolicy: usbPolicy
        )
        return EditorsAndProgramsViewModel(uploadViewModel: uploadViewModel, settings: settings, notificationCenter: notificationCenter)
    }
}
