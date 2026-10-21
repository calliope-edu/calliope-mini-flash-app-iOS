//
//  AppDependencies.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import UIKit

final class AppDependencies {
    let usbPolicy: USBTransferPolicy
    let usbDestinationPicker: USBDestinationPickerViewModel
    let connection: DeviceConnectionService
    let connectionPanel: MatrixConnectionViewModel
    let flashService: FlashService

    init() {
        usbPolicy = USBTransferPolicy(
            isSharedIPad: UIDevice.current.isSharedIPad,
            systemMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
        LogNotify.log("USB transfer: Shared iPad \(usbPolicy.isSharedIPad), destination picked per flash \(usbPolicy.picksDestinationPerFlash)")
        usbDestinationPicker = USBDestinationPickerViewModel()
        let service = CalliopeConnectionService(usbPolicy: usbPolicy, usbDestinationPicker: usbDestinationPicker)
        connection = service
        connectionPanel = MatrixConnectionViewModel(connection: service, usbPolicy: usbPolicy)
        flashService = FlashService(connection: connection)
        connection.start()
    }
}
