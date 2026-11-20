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
    let documentStorage: DocumentStorage
    let settings: SettingsStore
    let newsService: NewsService

    init() {
        usbPolicy = USBTransferPolicy(
            isSharedIPad: UIDevice.current.isSharedIPad,
            systemMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
        LogNotify.log("USB transfer: Shared iPad \(usbPolicy.isSharedIPad), destination picked per flash \(usbPolicy.picksDestinationPerFlash)")
        let settingsStore = UserDefaultsSettingsStore()
        settingsStore.prepareForLaunch(appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        settings = settingsStore
        usbDestinationPicker = USBDestinationPickerViewModel()
        let service = CalliopeConnectionService(usbPolicy: usbPolicy, usbDestinationPicker: usbDestinationPicker, settings: settings)
        connection = service
        connectionPanel = MatrixConnectionViewModel(connection: service, usbPolicy: usbPolicy)
        flashService = FlashService(connection: connection)
        documentStorage = FileDocumentStorage()
        newsService = RemoteNewsService(settings: settings)
        connection.start()
    }
}
