//
//  MatrixConnectionViewModel.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import CoreBluetooth

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
    
    func connect()
    func startUsbConnect()
    func handleUSBFolderPicked(_ url: URL)
    var isFolderPickerPresented: Bool { get set }
}

class MatrixConnectionViewModel: MatrixConnectionViewModelProtocol, Alertable {
    static let instance: MatrixConnectionViewModel = MatrixConnectionViewModel()
    
    @Published var matrix = Array(repeating: Array(repeating: false, count: 5), count: 5) {
        didSet {
            //matrix has been changed manually, this always triggers a disconnect
            self.connector.disconnectFromCalliope()
            self.connector.startCalliopeDiscovery()
            self.updateDiscoveryState()
        }
    }
    @Published var isInUsbMode = false {
        didSet {
            self.connector.disconnectFromCalliope()
        }
    }
    @Published var matrixInteractionEnabled = true
    @Published var connectionMenuButtonState: ConnectionMenuButtonState = .disconnected
    @Published var menuExpanded: Bool = false
    @Published var connectButtonState: ConnectButtonState = .initialized
    @Published var connectionMenuButtonBounceTrigger: Int = 0
    @Published var connectButtonBounceTrigger: Int = 0
    @Published var alert: (any AppAlert)? = nil
    @Published var isFolderPickerPresented = false

    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }

    let restoreLastMatrixEnabled = UserDefaults.standard.bool(forKey: SettingsKey.restoreLastMatrix.rawValue)
    private let queue = DispatchQueue(label: "bluetooth")
    
    private var attemptReconnect = false
    private var reconnecting = false
    private var delayedDiscovery = false
    
    var isInDfuMode: Bool = false
    
    public var discoveredCalliopeWithCurrentMatrix: DiscoveredDevice? {
        if isInUsbMode {
            return connector.discoveredCalliopes["USB_CALLIOPE"]
        } else {
            return connector.discoveredCalliopes[Matrix.matrix2friendly(matrix) ?? ""]
        }
    }
    
    public var usageReadyCalliope: Calliope? {
        if isInUsbMode {
            return connector.connectedUSBCalliope?.usageReadyCalliope
        } else {
            return connector.connectedCalliope?.usageReadyCalliope
        }
    }
    
     public var calliopeClass: DiscoveredBLEDevice.Type? = nil {
        didSet {
            guard calliopeClass != oldValue else {
                return
            }
            connectionDisabled = calliopeClass == nil
            guard let calliopeClass = calliopeClass else {
                return
            }
            let calliopeBuilder = { (_ peripheral: CBPeripheral, _ name: String) -> DiscoveredBLEDevice in
                return calliopeClass.init(peripheral: peripheral, name: name)
            }
            connector = CalliopeDiscovery(calliopeBuilder)
        }
    }
    
    private var connectionDisabled = true {
        didSet {
            if connectionDisabled {
                connectionMenuButtonState = .disabled
                connector.giveUpResponsibility()
            }
        }
    }
    
     public var connector: CalliopeDiscovery = CalliopeDiscovery({ peripheral, name in
        DiscoveredBLEDevice(peripheral: peripheral, name: name)
    })
    {
        didSet {
            self.changedConnector(oldValue)
        }
    }
    
    public func moveToForeground() {
        connector.isInBackground = false
        connector.startCalliopeDiscovery()
    }

    public func moveToBackground() {
        connector.isInBackground = true
        connector.stopCalliopeDiscovery()
    }

    public func dropBLEConnection() {
        connector.updateBlock = {
        }
        connector.isInBackground = true
        connector.stopCalliopeDiscovery()
        connector.disconnectFromCalliope()

    }
    
    public func restartFromBLEConnectionDrop() {
        connector.updateBlock = updateDiscoveryState
        connector.isInBackground = false
        connect()
    }

    private func changedConnector(_ oldValue: CalliopeDiscovery) {
        oldValue.giveUpResponsibility()
        connector.updateBlock = updateDiscoveryState
        connector.errorBlock = error
        connector.bluetoothStateChangedBlock = handleBluetoothStateChange
        restoreLastMatrix()
    }
    
    func matrixIsBlank() -> Bool {
        for row in matrix {
            for cell in row {
                if cell { return false }
            }
        }
        
        return true
    }
    
    func getMatrixString() -> String {
        var result = ""
        for b1 in matrix {
            for b2 in b1 {
                result += (b2 ? "1" : "0")
            }
        }
        return result
    }
    
    func setMatrixString(pattern:String) {
        if pattern.count != getMatrixString().count { return }
        
        var index = 0
        for (i1,b1) in matrix.enumerated() {
            for (i2,_) in b1.enumerated() {
                matrix[i1][i2] = (pattern[index] == "1") ? true : false
                index += 1
            }
        }
    }

    func restoreLastMatrix(overwrite: Bool = false) {
        if !restoreLastMatrixEnabled {
            return
        }
        if overwrite || matrixIsBlank() {
            setMatrixString(pattern: UserDefaults.standard.string(forKey: SettingsKey.lastMatrix.rawValue) ?? "")
        }
    }
    
    func startUsbConnect() {
        isFolderPickerPresented = true
    }

    func handleUSBFolderPicked(_ url: URL) {
        LogNotify.log("Start connection to USB Device")
        connector.handleUSBFolderPicked(url)
    }
    
    /// Prüft ob eine USB-Verbindung zum Calliope besteht
    public func isUSBConnected() -> Bool {
        return isInUsbMode && connector.discoveredCalliopes["USB_CALLIOPE"] != nil
    }
    
    func showFalseLocationAlert() {
        DispatchQueue.main.async {
            self.alert = WrongStorageLocationAlert()
        }
    }
    
    public func disconnectFromCalliope() {
        connector.disconnectFromCalliope()
    }
    
    public func onExpand() {
        if self.connector.state == .initialized {
                self.connector.startCalliopeDiscovery()
            }
    }
    
    public func onCollapse() {
        self.connector.stopCalliopeDiscovery()
    }
    
    public func animateBounce() {
        if menuExpanded {
//            self.connectButton.animateBounce()
        } else {
//            self.collapseButton.animateBounce()
        }
        print("Bouncing has to still be implemented")
    }  // Create a SwiftUI equivalent
    
    func connect() {
        if self.connector.state == .initialized && !isInUsbMode
            || self.discoveredCalliopeWithCurrentMatrix == nil && self.connector.state == .discoveredAll
        {
            connector.startCalliopeDiscovery()
        } else if let calliope = self.discoveredCalliopeWithCurrentMatrix {
            if isInUsbMode && self.connector.state == .usbConnected && calliope.state == .usageReady {
                return  // fine for USB, as no reconnect after transfer like BLE
            } else if calliope.state == .discovered {
                calliope.updateBlock = updateDiscoveryState
                calliope.errorBlock = error
                LogNotify.log("Matrix view connecting to \(calliope)")
                connector.connectToCalliope(calliope)
            } else if calliope.state == .connected {
                calliope.evaluateMode()
            } else {
                LogNotify.log(
                    "Connect button of matrix view should not be enabled in this state (\(self.connector.state), \(String(describing: self.discoveredCalliopeWithCurrentMatrix?.state)))"
                )
            }
        } else {
            LogNotify.log(
                "Connect button of matrix view should not be enabled in this state (\(self.connector.state), \(String(describing: self.discoveredCalliopeWithCurrentMatrix?.state)))"
            )
        }
    }
    
    private func updateDiscoveryState() {
        switch self.connector.state {
        case .initialized:
            matrixInteractionEnabled = true
            connectButtonState = .initialized
            connectionMenuButtonState = .disconnected
            restoreLastMatrix()
//            if !matrixIsBlank() {
//                startDelayedDiscovery()
//            }
        case .discoveryWaitingForBluetooth:
            matrixInteractionEnabled = true
            connectButtonState = .waitingForBluetooth
            connectionMenuButtonState = .disconnected
        case .discovering, .discovered:
            if let calliope = self.discoveredCalliopeWithCurrentMatrix {
                evaluateCalliopeState(calliope)
                if connectButtonState == .readyToConnect || calliope is DiscoveredUSBDevice {
                    connect()
                }
            } else {
                matrixInteractionEnabled = true
                connectButtonState = .searching
                connectionMenuButtonState = .disconnected
            }
        case .discoveredAll:
            if let calliope = self.discoveredCalliopeWithCurrentMatrix, calliope is DiscoveredUSBDevice {
                connect()
            } else {
                if let matchingCalliope = discoveredCalliopeWithCurrentMatrix {
                    evaluateCalliopeState(matchingCalliope)
                } else {
                    matrixInteractionEnabled = true
                    connectButtonState = .notFoundRetry
                    connectionMenuButtonState = .disconnected
//                    startDelayedDiscovery()
                }
            }
        case .connecting:
            matrixInteractionEnabled = false
            attemptReconnect = false
            reconnecting = false
            connectButtonState = .connecting
            connectionMenuButtonState = isInDfuMode ? .transmitting : .connecting
        case .connected:
            if let connectedCalliope = connector.connectedCalliope, discoveredCalliopeWithCurrentMatrix != connector.connectedCalliope {
                //set matrix in case of auto-reconnect, where we do not have corresponding matrix yet
                matrix = Matrix.friendly2Matrix(connectedCalliope.name)
                connectedCalliope.updateBlock = updateDiscoveryState
            }
            if let discoveredCalliopeWithCurrentMatrix = discoveredCalliopeWithCurrentMatrix {
                evaluateCalliopeState(discoveredCalliopeWithCurrentMatrix)
            } else {
                self.connector.disconnectFromCalliope()
            }

        case .usbConnecting:
            connectButtonState = .connecting
        case .usbConnected:
            if let connectedCalliope = connector.connectedUSBCalliope, discoveredCalliopeWithCurrentMatrix != connectedCalliope {
                connectedCalliope.updateBlock = updateDiscoveryState
            }
            evaluateCalliopeState(discoveredCalliopeWithCurrentMatrix!)
        }
    }
    
    public func enableDfuMode(mode: Bool) {
        isInDfuMode = mode
    }
    
    private func evaluateCalliopeState(_ calliope: DiscoveredDevice) {
        if isInDfuMode {
            return
        }
        if let usageReadyCalliope = calliope.usageReadyCalliope, usageReadyCalliope.rebootingIntoDFUMode, calliope.state == .discovered {
            connectionMenuButtonState = .connected
        } else if calliope.state == .wrongMode || calliope.state == .discovered {
            connectionMenuButtonState = (attemptReconnect || reconnecting) ? .connected : .disconnected
        } else if calliope.state == .usageReady {
            connectionMenuButtonState = .connected
            LogNotify.log("last pattern:\r\(getMatrixString())")
            UserDefaults.standard.set(getMatrixString(), forKey: SettingsKey.lastMatrix.rawValue)
        } else {
            connectionMenuButtonState = .connecting
        }

        if calliope.state == .discovered && attemptReconnect {
            //start reconnection attempt
            queue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.restartDuration, execute: connect)
            reconnecting = true
            attemptReconnect = false
            return
        }

        switch calliope.state {
        case .discovered:
            matrixInteractionEnabled = !reconnecting
            connectButtonState = reconnecting ? .connecting : .readyToConnect // The first was previously testingMode
        case .connected:
            reconnecting = false
            attemptReconnect = false
            matrixInteractionEnabled = false
            connectButtonState = .connecting // Previously testingMode
        case .evaluateMode:
            matrixInteractionEnabled = false
            connectButtonState = .connecting // Previously testingMode
        case .usageReady:
            // Verbindung erfolgreich - merken für Fehlerbehandlung
            hasEverConnected = true
            matrixInteractionEnabled = true
            connectButtonState = .readyToPlay
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                self.menuExpanded = false
            }
        case .wrongMode:
            matrixInteractionEnabled = true
            connectButtonState = .wrongProgram
        }
    }
    
    private var isShowingErrorAlert = false

    /// Speichert ob jemals eine erfolgreiche Verbindung hergestellt wurde
    /// Fehler werden nur angezeigt wenn dies true ist
    private var hasEverConnected = false

    /// Speichert ob bereits ein Bluetooth-Alert angezeigt wird
    private var isShowingBluetoothAlert = false
   
    
    private func handleBluetoothStateChange(_ state: CBManagerState) {
        // Show alert only when Bluetooth is powered off
        if state == .poweredOff && !isShowingBluetoothAlert {
            isShowingBluetoothAlert = true

            DispatchQueue.main.async {
                self.alert = BluetoothDeactivatedAlert(
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
    
    private func error(_ error: Error) {
        // Prüfe, ob bereits ein Fehler-Alert angezeigt wird
        if isShowingErrorAlert {
            return
        }

        if (error as? CBError)?.errorCode == 14 {
            // CBError 14 = Peer removed pairing information
            // Das passiert nach Verwendung einer anderen App (z.B. Blocks mit UART)
            DispatchQueue.main.async {
                self.alert = BluetoothResetRequiredAlert(
                    openSettings: {
                        // Öffnet die iOS Einstellungen (nicht App-Einstellungen!)
                        // Der Benutzer kann dann manuell zu Bluetooth navigieren
                        if let url = URL(string: "App-prefs:root=Bluetooth") {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                )
            }
        } else if error.localizedDescription == NSLocalizedString("Connection to calliope timed out!", comment: "") {
            // Timeout ignorieren wenn noch nie verbunden war
            if !hasEverConnected {
                LogNotify.log("Ignoring connection timeout - never connected before")
            } else {
                LogNotify.log("Ignoring connection timeout")  // Auch bei vorheriger Verbindung ignorieren (wie bisher)
            }
        } else if error.localizedDescription.contains("Calliope mini") && !hasEverConnected {
            // Andere Calliope-bezogene Fehler nur anzeigen wenn schon mal verbunden war
            LogNotify.log("Ignoring error - never connected before: \(error.localizedDescription)")
        } else {
            // TEMP: Alert deaktiviert - kann später wieder aktiviert werden
            LogNotify.log("Error suppressed (alert commented out): \(error.localizedDescription)")
        }
    }
    

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
}
