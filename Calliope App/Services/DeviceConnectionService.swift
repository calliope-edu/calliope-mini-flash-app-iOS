//
//  DeviceConnectionService.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import Foundation

protocol DeviceConnectionService: AnyObject {
    var currentCalliope: Calliope? { get }
    // Follows the BLE connection even while the USB switch is on, e.g. for sensors and web bluetooth.
    var bleCalliope: Calliope? { get }
    var isUsbMode: Bool { get }
    var isUsbConnected: Bool { get }
    var isBluetoothAvailable: Bool { get }
    var connectionLost: AnyPublisher<Void, Never> { get }
    var deviceDisconnected: AnyPublisher<String, Never> { get }

    func start()
    func enterForeground()
    func enterBackground()
    func suspendBluetooth()
    func resumeBluetooth()
    func reconnect(preferredName: String?)
    func setDfuMode(_ enabled: Bool)
    func disconnectForReboot()
    func resetUsbConnectionAfterCopy()
}

final class PreviewDeviceConnectionService: DeviceConnectionService {
    var currentCalliope: Calliope? { nil }
    var bleCalliope: Calliope? { nil }
    var isUsbMode: Bool { false }
    var isUsbConnected: Bool { false }
    var isBluetoothAvailable: Bool { false }
    var connectionLost: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
    var deviceDisconnected: AnyPublisher<String, Never> { Empty().eraseToAnyPublisher() }

    func start() {}
    func enterForeground() {}
    func enterBackground() {}
    func suspendBluetooth() {}
    func resumeBluetooth() {}
    func reconnect(preferredName: String?) {}
    func setDfuMode(_ enabled: Bool) {}
    func disconnectForReboot() {}
    func resetUsbConnectionAfterCopy() {}
}
