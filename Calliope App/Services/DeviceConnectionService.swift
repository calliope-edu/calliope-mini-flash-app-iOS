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

// What the connection panel needs on top: choosing the device and following the connection state.
protocol ConnectionControl: DeviceConnectionService {
    var state: DeviceConnectionState { get }
    var stateChanges: AnyPublisher<DeviceConnectionState, Never> { get }
    var matrix: [[Bool]] { get }
    var matrixChanges: AnyPublisher<[[Bool]], Never> { get }
    var usbModeChanges: AnyPublisher<Bool, Never> { get }
    var events: AnyPublisher<DeviceConnectionEvent, Never> { get }

    func select(matrix: [[Bool]])
    func setMatrixString(pattern: String)
    func setUsbMode(_ enabled: Bool)
    func connect()
    func startUsbConnect()
    func connectExportPickerUsb()
    func useUsbFolder(_ url: URL)
}

final class PreviewDeviceConnectionService: ConnectionControl {
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

    var state: DeviceConnectionState { .idle }
    var stateChanges: AnyPublisher<DeviceConnectionState, Never> { Just(.idle).eraseToAnyPublisher() }
    var matrix: [[Bool]] { Array(repeating: Array(repeating: false, count: 5), count: 5) }
    var matrixChanges: AnyPublisher<[[Bool]], Never> { Just(matrix).eraseToAnyPublisher() }
    var usbModeChanges: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }
    var events: AnyPublisher<DeviceConnectionEvent, Never> { Empty().eraseToAnyPublisher() }

    func select(matrix: [[Bool]]) {}
    func setMatrixString(pattern: String) {}
    func setUsbMode(_ enabled: Bool) {}
    func connect() {}
    func startUsbConnect() {}
    func connectExportPickerUsb() {}
    func useUsbFolder(_ url: URL) {}
}
