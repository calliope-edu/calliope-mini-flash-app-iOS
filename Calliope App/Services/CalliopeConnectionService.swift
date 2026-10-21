//
//  CalliopeConnectionService.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import CoreBluetooth
import UIKit

final class CalliopeConnectionService: ConnectionControl, CalliopeDiscoveryContext {

    private let makeDiscovery: DeviceDiscovery.Factory
    private let usbPolicy: USBTransferPolicy
    private let usbDestinationPicker: USBDestinationPicker
    private let stateSubject = CurrentValueSubject<DeviceConnectionState, Never>(.idle)
    private let matrixSubject = CurrentValueSubject<[[Bool]], Never>(Array(repeating: Array(repeating: false, count: 5), count: 5))
    private let usbModeSubject = CurrentValueSubject<Bool, Never>(false)
    private let eventSubject = PassthroughSubject<DeviceConnectionEvent, Never>()
    private let connectionLostSubject = PassthroughSubject<Void, Never>()
    private let deviceDisconnectedSubject = PassthroughSubject<String, Never>()

    private let restoreLastMatrixEnabled = UserDefaults.standard.bool(forKey: SettingsKey.restoreLastMatrix.rawValue)
    private var isStarted = false
    private var isInDfuMode = false
    private var hasEverConnected = false

    private var connector: DeviceDiscovery {
        didSet {
            changedConnector(oldValue)
        }
    }

    init(
        usbPolicy: USBTransferPolicy,
        usbDestinationPicker: USBDestinationPicker,
        makeDiscovery: @escaping DeviceDiscovery.Factory = { CalliopeDiscovery($0, context: $1) }
    ) {
        self.usbPolicy = usbPolicy
        self.usbDestinationPicker = usbDestinationPicker
        self.makeDiscovery = makeDiscovery
        connector = makeDiscovery(Self.buildBLEDevice, nil)
        connector.context = self
        forwardDisconnects(of: connector)
    }

    // MARK: - State

    var state: DeviceConnectionState {
        stateSubject.value
    }

    var stateChanges: AnyPublisher<DeviceConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var matrix: [[Bool]] {
        matrixSubject.value
    }

    var matrixChanges: AnyPublisher<[[Bool]], Never> {
        matrixSubject.eraseToAnyPublisher()
    }

    var isUsbMode: Bool {
        usbModeSubject.value
    }

    var usbModeChanges: AnyPublisher<Bool, Never> {
        usbModeSubject.eraseToAnyPublisher()
    }

    var events: AnyPublisher<DeviceConnectionEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    var currentCalliope: Calliope? {
        isUsbMode ? connector.connectedUSBDevice?.usageReadyCalliope : connector.connectedBLEDevice?.usageReadyCalliope
    }

    var bleCalliope: Calliope? {
        connector.connectedBLEDevice?.usageReadyCalliope
    }

    var isUsbConnected: Bool {
        isUsbMode && connector.discoveredCalliopes[Self.usbDeviceName] != nil
    }

    // TODO: Find a better measure of whether bluetooth is enabled
    var isBluetoothAvailable: Bool {
        connector.state != .initialized
    }

    var deviceDisconnected: AnyPublisher<String, Never> {
        deviceDisconnectedSubject.eraseToAnyPublisher()
    }

    var connectionLost: AnyPublisher<Void, Never> {
        connectionLostSubject.eraseToAnyPublisher()
    }

    var isConnectionEnabled: Bool {
        isStarted
    }

    var matrixString: String {
        matrix.flatMap { $0 }.map { $0 ? "1" : "0" }.joined()
    }

    private var selectedDevice: DiscoveredDevice? {
        if isUsbMode {
            return connector.discoveredCalliopes[Self.usbDeviceName]
        } else {
            return connector.discoveredCalliopes[Matrix.matrix2friendly(matrix) ?? ""]
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !isStarted else {
            return
        }
        isStarted = true
        connector = makeDiscovery(Self.buildBLEDevice, self)
    }

    func enterForeground() {
        connector.isInBackground = false
        connector.startCalliopeDiscovery()
    }

    func enterBackground() {
        connector.isInBackground = true
        connector.stopCalliopeDiscovery()
    }

    func suspendBluetooth() {
        connector.updateBlock = {}
        connector.isInBackground = true
        connector.stopCalliopeDiscovery()
        connector.disconnectFromCalliope()
    }

    func resumeBluetooth() {
        connector.updateBlock = updateDiscoveryState
        connector.isInBackground = false
        connect()
    }

    // MARK: - Selecting a device

    func select(matrix: [[Bool]]) {
        matrixSubject.send(matrix)
        // A changed selection always drops the current device.
        connector.disconnectFromCalliope()
        connector.startCalliopeDiscovery()
        updateDiscoveryState()
    }

    func setMatrixString(pattern: String) {
        guard pattern.count == 25 else {
            return
        }
        let cells = pattern.map { $0 == "1" }
        select(matrix: (0..<5).map { row in Array(cells[(row * 5)..<(row * 5 + 5)]) })
    }

    func setUsbMode(_ enabled: Bool) {
        usbModeSubject.send(enabled)
        connector.disconnectFromCalliope()
    }

    func connect() {
        if connector.state == .initialized && !isUsbMode
            || selectedDevice == nil && connector.state == .discoveredAll
        {
            connector.startCalliopeDiscovery()
        } else if let calliope = selectedDevice {
            if isUsbMode && connector.state == .usbConnected && calliope.state == .usageReady {
                return  // fine for USB, as no reconnect after transfer like BLE
            } else if calliope.state == .discovered {
                calliope.updateBlock = updateDiscoveryState
                calliope.errorBlock = error
                LogNotify.log("Connecting to \(calliope)")
                connector.connectToCalliope(calliope)
            } else if calliope.state == .connected {
                calliope.evaluateMode()
            } else {
                LogNotify.log("Connect should not be possible in this state (\(connector.state), \(String(describing: selectedDevice?.state)))")
            }
        } else {
            LogNotify.log("Connect should not be possible in this state (\(connector.state), \(String(describing: selectedDevice?.state)))")
        }
    }

    func reconnect(preferredName: String?) {
        guard connector.state != .connecting,
            let target = reconnectTarget(preferredName: preferredName),
            target.state == .discovered
        else {
            return
        }
        connector.connectToCalliope(target)
    }

    // MARK: - USB

    func startUsbConnect() {
        connector.startUsbConnect()
    }

    func connectExportPickerUsb() {
        connector.connectUsbCalliope(to: .pickPerFlash(usbDestinationPicker))
    }

    func useUsbFolder(_ url: URL) {
        LogNotify.log("Start connection to USB Device")
        connector.connectUsbCalliope(to: .folder(url))
    }

    func resetUsbConnectionAfterCopy() {
        guard usbPolicy.dropsConnectionAfterCancelledCopy, isUsbMode else { return }

        // Next main-queue turn: the finish callback may still run a connect() of its own, and this teardown has to win.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isUsbMode else { return }
            LogNotify.log("USB copy finished - dropping connection and switching USB off")
            self.setUsbMode(false)
        }
    }

    func reportInvalidUsbLocation() {
        eventSubject.send(.invalidUsbLocation)
    }

    // MARK: - Flashing

    func setDfuMode(_ enabled: Bool) {
        isInDfuMode = enabled
    }

    func disconnectForReboot() {
        connector.disconnectForReboot()
    }

    // MARK: - Private Helpers

    private static let usbDeviceName = "USB_CALLIOPE"

    private static func buildBLEDevice(peripheral: CBPeripheral, name: String) -> DiscoveredBLEDevice {
        DiscoveredBLEDevice(peripheral: peripheral, name: name)
    }

    private func changedConnector(_ oldValue: DeviceDiscovery) {
        oldValue.giveUpResponsibility()
        connector.updateBlock = updateDiscoveryState
        connector.errorBlock = error
        connector.bluetoothStateChangedBlock = { [weak self] state in
            self?.eventSubject.send(.bluetoothStateChanged(state))
        }
        forwardDisconnects(of: connector)
        restoreLastMatrix()
    }

    private func forwardDisconnects(of connector: DeviceDiscovery) {
        _ = connector.registerDisconnectNotification { [weak self] uuid in
            self?.deviceDisconnectedSubject.send(uuid)
        }
    }

    private func restoreLastMatrix() {
        guard restoreLastMatrixEnabled, !matrix.joined().contains(true) else {
            return
        }
        setMatrixString(pattern: UserDefaults.standard.string(forKey: SettingsKey.lastMatrix.rawValue) ?? "")
    }

    // The preferred mini if visible, else the single visible BLE mini if unambiguous.
    private func reconnectTarget(preferredName: String?) -> DiscoveredDevice? {
        if let preferredName, let device = connector.discoveredCalliopes[preferredName] {
            return device
        }
        let bleDevices = connector.discoveredCalliopes.values.filter { !($0 is DiscoveredUSBDevice) }
        return bleDevices.count == 1 ? bleDevices.first : nil
    }

    private func updateDiscoveryState() {
        switch connector.state {
        case .initialized:
            stateSubject.send(.idle)
            restoreLastMatrix()
        case .discoveryWaitingForBluetooth:
            stateSubject.send(.waitingForBluetooth)
        case .discovering, .discovered:
            if let calliope = selectedDevice {
                evaluateCalliopeState(calliope)
                if case .readyToConnect = state {
                    connect()
                } else if calliope is DiscoveredUSBDevice {
                    connect()
                }
            } else {
                stateSubject.send(.searching)
            }
        case .discoveredAll:
            if let calliope = selectedDevice, calliope is DiscoveredUSBDevice {
                connect()
            } else if let calliope = selectedDevice {
                evaluateCalliopeState(calliope)
            } else {
                stateSubject.send(.notFound)
            }
        case .connecting:
            stateSubject.send(isInDfuMode ? .transmitting : .connecting)
        case .connected:
            if let connectedCalliope = connector.connectedBLEDevice, selectedDevice != connectedCalliope {
                // Auto-reconnect, where we do not have the matching matrix yet.
                select(matrix: Matrix.friendly2Matrix(connectedCalliope.name))
                connectedCalliope.updateBlock = updateDiscoveryState
            }
            if let calliope = selectedDevice {
                evaluateCalliopeState(calliope)
            } else {
                connector.disconnectFromCalliope()
            }
        case .usbConnecting:
            stateSubject.send(.usbConnecting)
        case .usbConnected:
            if let connectedCalliope = connector.connectedUSBDevice, selectedDevice != connectedCalliope {
                connectedCalliope.updateBlock = updateDiscoveryState
            }
            evaluateCalliopeState(selectedDevice!)
        }
    }

    private func evaluateCalliopeState(_ calliope: DiscoveredDevice) {
        guard !isInDfuMode else {
            return
        }
        switch calliope.state {
        case .discovered:
            stateSubject.send(.readyToConnect(rebooting: calliope.usageReadyCalliope?.rebootingIntoDFUMode ?? false))
        case .connected, .evaluateMode:
            stateSubject.send(.preparing)
        case .usageReady:
            LogNotify.log("last pattern:\r\(matrixString)")
            UserDefaults.standard.set(matrixString, forKey: SettingsKey.lastMatrix.rawValue)
            hasEverConnected = true
            stateSubject.send(.ready)
        case .wrongMode:
            stateSubject.send(.wrongProgram)
        }
    }

    private func error(_ error: Error) {
        if (error as? CBError)?.errorCode == CBError.peerRemovedPairingInformation.rawValue {
            // Happens after another app (e.g. Blocks with UART) paired with the mini.
            DispatchQueue.main.async {
                self.eventSubject.send(.pairingRemoved)
                // A gone peripheral never reaches the DFU library's finished/failed callback.
                self.connectionLostSubject.send()
            }
        } else if error.localizedDescription == NSLocalizedString("Connection to calliope timed out!", comment: "") {
            LogNotify.log(hasEverConnected ? "Ignoring connection timeout" : "Ignoring connection timeout - never connected before")
        } else if error.localizedDescription.contains("Calliope mini") && !hasEverConnected {
            LogNotify.log("Ignoring error - never connected before: \(error.localizedDescription)")
        } else {
            LogNotify.log("Error suppressed: \(error.localizedDescription)")
        }
    }
}
