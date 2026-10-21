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
    let usbPolicy: USBTransferPolicy

    init() {
        connectionPanel = .instance
        connection = connectionPanel.connection
        usbPolicy = connectionPanel.usbPolicy
        LogNotify.log("USB transfer: Shared iPad \(usbPolicy.isSharedIPad), destination picked per flash \(usbPolicy.picksDestinationPerFlash)")
        flashService = FlashService(connection: connection)
        connection.start()
    }
}
