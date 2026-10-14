//
//  AppDependencies.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

final class AppDependencies {
    let connectionPanel: MatrixConnectionViewModel
    let connection: DeviceConnectionService
    let flashService: FlashService

    init() {
        connectionPanel = .instance
        connection = MatrixDeviceConnectionService(viewModel: connectionPanel)
        flashService = FlashService(connection: connection)
        connection.start()
    }
}
