//
//  MatrixConnectionViewModel.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import CoreBluetooth
import Foundation
import SwiftUI

enum ConnectionMenuButtonState {
    case disabled
    case disconnected
    case connecting
    case connected
    case transmitting
}

public enum ConnectButtonState {
    case initialized
    case waitingForBluetooth
    case searching
    case notFoundRetry
    case readyToConnect
    case connecting
    case readyToPlay
    case wrongProgram
}

protocol MatrixConnectionViewModelProtocol: ObservableObject {
    var matrix: [[Bool]] { get set }
    var isInUsbMode: Bool { get set }
    var matrixInteractionEnabled: Bool { get }
    var connectionMenuButtonState: ConnectionMenuButtonState { get }
    var menuExpanded: Bool { get set }
    var connectButtonState: ConnectButtonState { get }
    var connectionMenuButtonBounceTrigger: Int { get }
    var connectButtonBounceTrigger: Int { get }
    var isSharedIpad: Bool { get }

    func connect()
    func startUsbConnect()
    func handleUSBFolderPicked(_ url: URL)
    var isFolderPickerPresented: Bool { get set }
    func animateBounce()
}

class MatrixConnectionViewModel: MatrixConnectionViewModelProtocol, Alertable, ConnectionPanel {
    // Only USBCalliope still reaches the panel through the singleton; AppDependencies takes it from here.
    static let instance = MatrixConnectionViewModel(connection: CalliopeConnectionService())

    let connection: ConnectionControl
    private var subscriptions: Set<AnyCancellable> = []

    init(connection: ConnectionControl) {
        self.connection = connection
        connection.matrixChanges
            .sink { [weak self] matrix in
                guard let self, self.matrix != matrix else { return }
                self.matrix = matrix
            }
            .store(in: &subscriptions)
        connection.usbModeChanges
            .sink { [weak self] isUsbMode in
                guard let self, self.isInUsbMode != isUsbMode else { return }
                self.isInUsbMode = isUsbMode
            }
            .store(in: &subscriptions)
        connection.stateChanges
            .sink { [weak self] state in self?.apply(state) }
            .store(in: &subscriptions)
        connection.events
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &subscriptions)
    }

    @Published var matrix = Array(repeating: Array(repeating: false, count: 5), count: 5) {
        didSet {
            guard matrix != connection.matrix else { return }
            connection.select(matrix: matrix)
        }
    }
    @Published var isInUsbMode = false {
        didSet {
            if isInUsbMode != connection.isUsbMode {
                connection.setUsbMode(isInUsbMode)
            }

            // Where the destination is picked per flash (Shared iPad, iPadOS < 26),
            // flipping the switch is already the whole decision: connect right away
            // instead of waiting for the confirmation button below it, which is easy
            // to overlook. The heads-up alert and the green connection icon then
            // appear immediately.
            //
            // iPadOS 26+ on a personal device keeps the button: there the folder
            // picker opens and needs a deliberate action anyway.
            //
            // Only on switching ON — `resetUsbConnectionAfterCopy` switches it off,
            // so this cannot loop.
            if isInUsbMode, UIDevice.current.usbNeedsExportPicker {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isInUsbMode else { return }
                    LogNotify.log("USB switch turned on - connecting straight away (export-picker device)")
                    self.startUsbConnect()
                }
            }
        }
    }
    @Published var matrixInteractionEnabled = true
    @Published var connectionMenuButtonState: ConnectionMenuButtonState = .disconnected
    @Published var menuExpanded: Bool = false
    @Published var connectButtonState: ConnectButtonState = .initialized
    @Published var connectionMenuButtonBounceTrigger: Int = 0
    @Published var connectButtonBounceTrigger: Int = 0
    @Published var alert: AppAlert? = nil
    @Published var isFolderPickerPresented = false

    var alertBinding: Binding<AppAlert?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }
    @Published var isSharedIpad: Bool = UIDevice.current.isSharedIPad
    @Published private(set) var usbExportRequest: UsbExportRequest?

    var usbExportPresentedBinding: Binding<Bool> {
        Binding(
            get: { self.usbExportRequest != nil },
            set: { isPresented in
                guard !isPresented, let request = self.usbExportRequest else { return }
                // iOS 16 has no cancel callback; the delay lets a success result arrive first.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard self.usbExportRequest?.id == request.id else { return }
                    self.completeUsbExport(nil)
                }
            }
        )
    }

    /// Whether the one-time heads-up alert before the per-flash export picker
    /// has already been shown in this app session. Reset on each app launch so
    /// a fresh user of a shared device sees it once.
    private var hasShownUsbPickerAlert = false

    private var isShowingBluetoothAlert = false

    func setMatrixString(pattern: String) {
        connection.setMatrixString(pattern: pattern)
    }

    func connect() {
        connection.connect()
    }

    func startUsbConnect() {
        connection.startUsbConnect()

        // Where no writable folder URL can be obtained (Shared iPad, or any
        // iPadOS below 26), skip the folder picker and fall back to picking the
        // destination per flash via the export picker. A one-time heads-up
        // alert explains that before the first USB activation of a session;
        // later activations connect straight away.
        if UIDevice.current.usbNeedsExportPicker {
            guard !hasShownUsbPickerAlert else {
                connection.connectExportPickerUsb()
                return
            }
            hasShownUsbPickerAlert = true
            alert = .usbExportPickerNotice(isSharedIPad: isSharedIpad) { [weak self] in
                self?.connection.connectExportPickerUsb()
            }
            return
        }

        // Personal iPad: use the existing folder-picker flow.
        isFolderPickerPresented = true
    }

    func requestUsbExport(filename: String, completion: @escaping (Result<URL, Error>?) -> Void) {
        usbExportRequest = UsbExportRequest(filename: filename, completion: completion)
    }

    // A nil result means the user cancelled the export picker.
    func completeUsbExport(_ result: Result<URL, Error>?) {
        guard let request = usbExportRequest else { return }
        usbExportRequest = nil
        request.completion(result)
    }

    func handleUSBFolderPicked(_ url: URL) {
        connection.useUsbFolder(url)
    }

    public func animateBounce() {
        if menuExpanded {
            connectButtonBounceTrigger += 1
        } else {
            connectionMenuButtonBounceTrigger += 1
        }
    }

    // MARK: - Private Helpers

    private func apply(_ state: DeviceConnectionState) {
        switch state {
        case .idle:
            show(interaction: true, button: .initialized, menu: .disconnected)
        case .waitingForBluetooth:
            show(interaction: true, button: .waitingForBluetooth, menu: .disconnected)
        case .searching:
            show(interaction: true, button: .searching, menu: .disconnected)
        case .notFound:
            show(interaction: true, button: .notFoundRetry, menu: .disconnected)
        case .connecting:
            show(interaction: false, button: .connecting, menu: .connecting)
        case .transmitting:
            show(interaction: false, button: .connecting, menu: .transmitting)
        case .usbConnecting:
            connectButtonState = .connecting
        case .readyToConnect(let rebooting):
            show(interaction: true, button: .readyToConnect, menu: rebooting ? .connected : .disconnected)
        case .preparing:
            show(interaction: false, button: .connecting, menu: .connecting)
        case .ready:
            show(interaction: true, button: .readyToPlay, menu: .connected)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                self.menuExpanded = false
            }
        case .wrongProgram:
            show(interaction: true, button: .wrongProgram, menu: .disconnected)
        }
    }

    private func show(interaction: Bool, button: ConnectButtonState, menu: ConnectionMenuButtonState) {
        matrixInteractionEnabled = interaction
        connectButtonState = button
        connectionMenuButtonState = menu
    }

    private func handle(_ event: DeviceConnectionEvent) {
        switch event {
        case .bluetoothStateChanged(let state):
            handleBluetoothStateChange(state)
        case .pairingRemoved:
            alert = .bluetoothResetRequired(
                openSettings: {
                    // Opens the iOS settings, not the app settings, so the user can go to Bluetooth.
                    if let url = URL(string: "App-prefs:root=Bluetooth") {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            )
        case .invalidUsbLocation:
            DispatchQueue.main.async {
                self.alert = .wrongStorageLocation()
            }
        }
    }

    private func handleBluetoothStateChange(_ state: CBManagerState) {
        // Show alert only when Bluetooth is powered off
        if state == .poweredOff && !isShowingBluetoothAlert {
            isShowingBluetoothAlert = true

            DispatchQueue.main.async {
                self.alert = .bluetoothDeactivated(
                    openSettings: { [weak self] in
                        self?.isShowingBluetoothAlert = false
                        // Open iOS Settings app - Bluetooth section
                        if let url = URL(string: "App-prefs:root=Bluetooth") {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    },
                    ok: { [weak self] in
                        self?.isShowingBluetoothAlert = false
                    }
                )
            }
        } else if state == .poweredOn {
            // Reset flag when Bluetooth is turned back on
            isShowingBluetoothAlert = false
        }
    }
}

struct UsbExportRequest {
    let id = UUID()
    let filename: String
    let completion: (Result<URL, Error>?) -> Void
}

class PreviewMatrixConnectionViewModel: MatrixConnectionViewModelProtocol {
    @Published var matrix = Array(repeating: Array(repeating: false, count: 5), count: 5)
    @Published var isInUsbMode = false
    @Published var matrixInteractionEnabled = true
    @Published var connectionMenuButtonState: ConnectionMenuButtonState
    @Published var menuExpanded: Bool = false
    @Published var connectButtonState: ConnectButtonState
    @Published var connectionMenuButtonBounceTrigger: Int = 0
    @Published var connectButtonBounceTrigger: Int = 0
    @Published var isFolderPickerPresented = false
    @Published var isSharedIpad: Bool = false

    init(connectionMenuButtonState: ConnectionMenuButtonState = .disconnected, connectButtonState: ConnectButtonState = .readyToConnect) {
        self.connectionMenuButtonState = connectionMenuButtonState
        self.connectButtonState = connectButtonState
    }

    func connect() {
        LogNotify.log("Pressed connect")
        connectionMenuButtonBounceTrigger += 1
        connectButtonBounceTrigger += 1
    }

    func startUsbConnect() {
        isFolderPickerPresented = true
    }

    func handleUSBFolderPicked(_ url: URL) {
        LogNotify.log("Pressed startUsbConnect")
    }

    public func animateBounce() {
        if menuExpanded {
            connectButtonBounceTrigger += 1
        } else {
            connectionMenuButtonBounceTrigger += 1
        }
    }
}
