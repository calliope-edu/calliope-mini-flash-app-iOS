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

    var bleCalliope: Calliope? {
        viewModel.connector.connectedBLEDevice?.usageReadyCalliope
    }

    var isUsbMode: Bool {
        viewModel.isInUsbMode
    }

    var isUsbConnected: Bool {
        viewModel.isUSBConnected()
    }

    // TODO: Find a better measure of whether bluetooth is enabled
    var isBluetoothAvailable: Bool {
        viewModel.connector.state != .initialized
    }

    var connectionLost: AnyPublisher<Void, Never> {
        viewModel.connectionLost.eraseToAnyPublisher()
    }

    var deviceDisconnected: AnyPublisher<String, Never> {
        viewModel.deviceDisconnected.eraseToAnyPublisher()
    }

    func start() {
        viewModel.calliopeClass = DiscoveredBLEDevice.self
    }

    func enterForeground() {
        viewModel.moveToForeground()
    }

    func enterBackground() {
        viewModel.moveToBackground()
    }

    func suspendBluetooth() {
        viewModel.dropBLEConnection()
    }

    func resumeBluetooth() {
        viewModel.restartFromBLEConnectionDrop()
    }

    func reconnect(preferredName: String?) {
        let connector = viewModel.connector
        guard connector.state != .connecting,
            let target = reconnectTarget(in: connector, preferredName: preferredName),
            target.state == .discovered
        else {
            return
        }
        connector.connectToCalliope(target)
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

    // The preferred mini if visible, else the single visible BLE mini if unambiguous.
    private func reconnectTarget(in connector: DeviceDiscovery, preferredName: String?) -> DiscoveredDevice? {
        if let preferredName, let device = connector.discoveredCalliopes[preferredName] {
            return device
        }
        let bleDevices = connector.discoveredCalliopes.values.filter { !($0 is DiscoveredUSBDevice) }
        return bleDevices.count == 1 ? bleDevices.first : nil
    }
}
