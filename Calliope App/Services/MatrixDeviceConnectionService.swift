//
//  MatrixDeviceConnectionService.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import Foundation

// Thin wrapper until the non-UI connection state moves out of MatrixConnectionViewModel.
final class MatrixDeviceConnectionService: DeviceConnectionService {

    private let viewModel: MatrixConnectionViewModel

    init(viewModel: MatrixConnectionViewModel) {
        self.viewModel = viewModel
    }

    var currentCalliope: Calliope? {
        viewModel.usageReadyCalliope
    }

    var connectionLost: AnyPublisher<Void, Never> {
        viewModel.connectionLost.eraseToAnyPublisher()
    }

    func setDfuMode(_ enabled: Bool) {
        viewModel.enableDfuMode(mode: enabled)
    }

    func disconnectForReboot() {
        viewModel.connector.disconnectForReboot()
    }

    func resetUsbConnectionAfterCopy() {
        viewModel.resetUsbConnectionAfterCopy()
    }
}
