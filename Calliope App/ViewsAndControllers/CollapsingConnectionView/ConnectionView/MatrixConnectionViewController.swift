//
//  MatrixConnectionViewController.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 14.12.18.
//

import CoreBluetooth
import UIKit

class MatrixConnectionViewController: UIViewController, CollapsingViewControllerProtocol {

    @IBOutlet weak var connectionDescriptionLabel: UILabel!

    public static var instance: MatrixConnectionViewController!

    /// button to toggle whether connection view is open or not
    @IBOutlet var collapseButton: ConnectionViewCollapseButton!
    var collapseButtonView: (CollapseButtonProtocol & UIView)! {
        return collapseButton
    }
    //gesture recognizer added to background when open
    lazy var collapseGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleOpen(_:)))

    /// the view which handles the collapsing
    @IBOutlet var zoomView: UIView!

    /// constraint to collapse view horizontally
    @IBOutlet var collapseWidthConstraint: NSLayoutConstraint!
    /// constraint to collapse view vertically
    @IBOutlet var collapseHeightConstraint: NSLayoutConstraint!

    @IBOutlet var usbSwitchHeightConstraint: NSLayoutConstraint!

    @IBOutlet var usbSwitch: UISwitch!
    var isInUsbMode: Bool = false

    /// the matrix in which to draw the calliope name pattern
    @IBOutlet var matrixView: MatrixView!

    @IBOutlet var matrixSuperView: UIView!

    @IBOutlet var bluetoothSuperView: UIView!

    @IBOutlet var usbSuperView: UIView!

    @IBOutlet var overallStackView: UIStackView!

    @IBOutlet var usbSwitchSuperView: UIView!

    /// button to trigger the connection with the calliope
    @IBOutlet var connectButton: ConnectionButton!

    let collapsedWidth: CGFloat = 50
    let collapsedHeight: CGFloat = 50
    let expandedWidth: CGFloat = 274
    var expandedHeight: CGFloat = 500

    let restoreLastMatrixEnabled = UserDefaults.standard.bool(forKey: SettingsKey.restoreLastMatrix.rawValue)

    private let queue = DispatchQueue(label: "bluetooth")

    public var connectionDescriptionText: String = NSLocalizedString("1. Programm 5 starten\n2. Schütteln\n3. LED-Muster eingeben", comment: "") {
        didSet {
            connectionDescriptionLabel.text = connectionDescriptionText
        }
    }

    public var discoveredCalliopeWithCurrentMatrix: DiscoveredDevice? {
        if isInUsbMode {
            return connector.discoveredCalliopes["USB_CALLIOPE"]
        } else {
            return connector.discoveredCalliopes[Matrix.matrix2friendly(matrixView.matrix) ?? ""]
        }
    }

    public var usageReadyCalliope: Calliope? {
        if isInUsbMode {
            return connector.connectedUSBCalliope?.usageReadyCalliope
        } else {
            return connector.connectedCalliope?.usageReadyCalliope
        }
    }

    public var calliopeClass: DiscoveredBLEDDevice.Type? = nil {
        didSet {
            guard calliopeClass != oldValue else {
                return
            }
            connectionDisabled = calliopeClass == nil
            guard let calliopeClass = calliopeClass else {
                return
            }
            let calliopeBuilder = { (_ peripheral: CBPeripheral, _ name: String) -> DiscoveredBLEDDevice in
                return calliopeClass.init(peripheral: peripheral, name: name)
            }
            connector = CalliopeDiscovery(calliopeBuilder)
        }
    }

    private var connectionDisabled = true {
        didSet {
            if connectionDisabled {
                animate(expand: false)
                collapseButton.connectionState = .disabled
                connector.giveUpResponsibility()
            }
        }
    }

    private var connector: CalliopeDiscovery = CalliopeDiscovery({ peripheral, name in
        DiscoveredBLEDDevice(peripheral: peripheral, name: name)
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
        matrixView.updateBlock = {
            //matrix has been changed manually, this always triggers a disconnect
            self.connector.disconnectFromCalliope()
            self.connector.startCalliopeDiscovery()
            self.updateDiscoveryState()
        }
        connector.isInBackground = false
        connect()
    }

    private func changedConnector(_ oldValue: CalliopeDiscovery) {
        oldValue.giveUpResponsibility()
        connector.updateBlock = updateDiscoveryState
        connector.errorBlock = error
        connector.bluetoothStateChangedBlock = handleBluetoothStateChange
        matrixView.updateBlock = {
            //matrix has been changed manually, this always triggers a disconnect
            self.connector.disconnectFromCalliope()
            self.connector.startCalliopeDiscovery()
            self.updateDiscoveryState()
        }
        restoreLastMatrix()
    }

    func restoreLastMatrix(overwrite: Bool = false) {
        if !restoreLastMatrixEnabled {
            return
        }
        if overwrite || matrixView.isBlank() {
            matrixView.setMatrixString(pattern: UserDefaults.standard.string(forKey: SettingsKey.lastMatrix.rawValue) ?? "")
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        MatrixConnectionViewController.instance = self
        connectButton.imageView?.contentMode = .scaleAspectFit
        usbSuperView.isHidden = true
        usbSwitch.isOn = false
        usbSwitchSuperView.isHidden = false
        usbSwitch.addTarget(self, action: #selector(switchChanged), for: UIControl.Event.valueChanged)
        self.animate(expand: false, animate: false)
    }

    @IBAction @objc public func switchChanged(usbSwitch: UISwitch) {

        self.isInUsbMode = usbSwitch.isOn
        self.connector.disconnectFromCalliope()

        let viewToHide = (isInUsbMode ? self.bluetoothSuperView : self.usbSuperView)!
        let viewToShow = (isInUsbMode ? self.usbSuperView : self.bluetoothSuperView)!

        viewToShow.alpha = 0.0
        viewToHide.alpha = 1.0

        UIView.animate(
            withDuration: 0.1,
            animations: {
                viewToHide.alpha = 0.0
            }
        ) { completed in
            UIView.animate(withDuration: 0.2) {
                viewToHide.isHidden = true
                viewToShow.isHidden = false
                self.view.layoutIfNeeded()
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    viewToShow.alpha = 1.0
                }
            }
        }
    }


    @IBAction func toggleOpen(_ sender: Any) {
        self.parent?.view.removeGestureRecognizer(collapseGestureRecognizer)
        toggleOpen()
    }

    @IBAction func startUSBconnect(_ sender: Any) {
        LogNotify.log("Start connection to USB Device")
        self.connector.initializeConnectionToUsbCalliope(view: self)
    }

    /// Prüft ob eine USB-Verbindung zum Calliope besteht
    public func isUSBConnected() -> Bool {
        return isInUsbMode && connector.discoveredCalliopes["USB_CALLIOPE"] != nil
    }

    func showFalseLocationAlert() {
        let alert = UIAlertController(title: NSLocalizedString("Wrong storage location", comment: ""), message: NSLocalizedString("You have not selected a Calliope folder as storage location", comment: ""), preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            })
        self.present(alert, animated: true)
    }

    public func disconnectFromCalliope() {
        connector.disconnectFromCalliope()
    }

    func animationCompletions(expand: Bool) {
        //start or end calliope discovery
        if expand {
            if self.connector.state == .initialized {
                self.connector.startCalliopeDiscovery()
            }
        } else {
            self.connector.stopCalliopeDiscovery()
        }

        //add gesture recognizer to background for dismissal
        if expand {
            self.parent?.view.addGestureRecognizer(collapseGestureRecognizer)
        }
    }

    public func animateBounce() {
        if collapseButton.expansionState == .open {
            self.connectButton.animateBounce()
        } else {
            self.collapseButton.animateBounce()
        }
    }

    // MARK: calliope connection

    private var attemptReconnect = false
    private var reconnecting = false
    private var delayedDiscovery = false

    @IBAction func connect() {
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
                LogNotify.log("Connect button of matrix view should not be enabled in this state (\(self.connector.state), \(String(describing: self.discoveredCalliopeWithCurrentMatrix?.state)))")
            }
        } else {
            LogNotify.log("Connect button of matrix view should not be enabled in this state (\(self.connector.state), \(String(describing: self.discoveredCalliopeWithCurrentMatrix?.state)))")
        }
    }

    private func updateDiscoveryState() {
        switch self.connector.state {
        case .initialized:
            matrixView.isUserInteractionEnabled = true
            connectButton.connectionState = .initialized
            self.collapseButton.connectionState = .disconnected
            restoreLastMatrix()
            if !matrixView.isBlank() {
                startDelayedDiscovery()
            }
        case .discoveryWaitingForBluetooth:
            matrixView.isUserInteractionEnabled = true
            connectButton.connectionState = .waitingForBluetooth
            self.collapseButton.connectionState = .disconnected
        case .discovering, .discovered:
            if let calliope = self.discoveredCalliopeWithCurrentMatrix {
                evaluateCalliopeState(calliope)
                if connectButton.connectionState == .readyToConnect || calliope is DiscoveredUSBDevice {
                    connect()
                }
            } else {
                matrixView.isUserInteractionEnabled = true
                connectButton.connectionState = .searching
                self.collapseButton.connectionState = .disconnected
            }
        case .discoveredAll:
            if let calliope = self.discoveredCalliopeWithCurrentMatrix, calliope is DiscoveredUSBDevice {
                connect()
            } else {
                if let matchingCalliope = discoveredCalliopeWithCurrentMatrix {
                    evaluateCalliopeState(matchingCalliope)
                } else {
                    matrixView.isUserInteractionEnabled = true
                    connectButton.connectionState = .notFoundRetry
                    self.collapseButton.connectionState = .disconnected
                    startDelayedDiscovery()
                }
            }
        case .connecting:
            matrixView.isUserInteractionEnabled = false
            attemptReconnect = false
            reconnecting = false
            connectButton.connectionState = .connecting
            self.collapseButton.connectionState = isInDfuMode ? .transmitting : .connecting
        case .connected:
            if let connectedCalliope = connector.connectedCalliope, discoveredCalliopeWithCurrentMatrix != connector.connectedCalliope {
                //set matrix in case of auto-reconnect, where we do not have corresponding matrix yet
                matrixView.matrix = Matrix.friendly2Matrix(connectedCalliope.name)
                connectedCalliope.updateBlock = updateDiscoveryState
            }
            if let discoveredCalliopeWithCurrentMatrix = discoveredCalliopeWithCurrentMatrix {
                evaluateCalliopeState(discoveredCalliopeWithCurrentMatrix)
            } else {
                self.connector.disconnectFromCalliope()
            }

        case .usbConnecting:
            connectButton.connectionState = .connecting
        case .usbConnected:
            if let connectedCalliope = connector.connectedUSBCalliope, discoveredCalliopeWithCurrentMatrix != connectedCalliope {
                connectedCalliope.updateBlock = updateDiscoveryState
            }
            evaluateCalliopeState(discoveredCalliopeWithCurrentMatrix!)
        }
    }

    private func startDelayedDiscovery(delaySeconds: Int = 7) {
        // remove Delayed Discovery for now, created endless loop of looking for Calliope, which is no longer required without an auto connect
        return
    }

    var isInDfuMode: Bool = false

    public func enableDfuMode(mode: Bool) {
        isInDfuMode = mode
    }

    private func evaluateCalliopeState(_ calliope: DiscoveredDevice) {
        if isInDfuMode {
            return
        }
        if let usageReadyCalliope = calliope.usageReadyCalliope, usageReadyCalliope.rebootingIntoDFUMode, calliope.state == .discovered {
            self.collapseButton.connectionState = .connected
        } else if calliope.state == .wrongMode || calliope.state == .discovered {
            self.collapseButton.connectionState = (attemptReconnect || reconnecting) ? .connected : .disconnected
        } else if calliope.state == .usageReady {
            self.collapseButton.connectionState = .connected
            LogNotify.log("last pattern:\r\(matrixView.getMatrixString())")
            UserDefaults.standard.set(matrixView.getMatrixString(), forKey: SettingsKey.lastMatrix.rawValue)
        } else {
            self.collapseButton.connectionState = .connecting
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
            matrixView.isUserInteractionEnabled = !reconnecting
            connectButton.connectionState = reconnecting ? .testingMode : .readyToConnect
        case .connected:
            reconnecting = false
            attemptReconnect = false
            matrixView.isUserInteractionEnabled = false
            connectButton.connectionState = .testingMode
        case .evaluateMode:
            matrixView.isUserInteractionEnabled = false
            connectButton.connectionState = .testingMode
        case .usageReady:
            // Verbindung erfolgreich - merken für Fehlerbehandlung
            hasEverConnected = true
            matrixView.isUserInteractionEnabled = true
            connectButton.connectionState = .readyToPlay
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                self.parent?.view.removeGestureRecognizer(self.collapseGestureRecognizer)
                self.animate(expand: false)
            }
        case .wrongMode:
            matrixView.isUserInteractionEnabled = true
            connectButton.connectionState = .wrongProgram
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

            let alertController = UIAlertController(
                title: NSLocalizedString("Bluetooth deactivated", comment: "Bluetooth is turned off"),
                message: NSLocalizedString("Bluetooth must be activated to send data to Calliope mini!", comment: "Bluetooth required message"),
                preferredStyle: .alert
            )

            // Button to open Bluetooth settings
            alertController.addAction(UIAlertAction(
                title: NSLocalizedString("Open Settings", comment: "Open Settings button"),
                style: .default,
                handler: { [weak self] _ in
                    self?.isShowingBluetoothAlert = false
                    // Open iOS Settings app - Bluetooth section
                    if let url = URL(string: "App-prefs:root=Bluetooth") {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            ))

            // OK button to dismiss
            alertController.addAction(UIAlertAction(
                title: "OK",
                style: .cancel,
                handler: { [weak self] _ in
                    self?.isShowingBluetoothAlert = false
                }
            ))

            self.show(alertController, sender: nil)
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

        let alertController: UIAlertController?

        if (error as? CBError)?.errorCode == 14 {
            // CBError 14 = Peer removed pairing information
            // Das passiert nach Verwendung einer anderen App (z.B. Blocks mit UART)
            alertController = UIAlertController(
                title: NSLocalizedString("Bluetooth-Verbindung zurücksetzen", comment: "Reset Bluetooth connection"),
                message: NSLocalizedString("Der Calliope mini wurde zuvor mit Blocks verbunden. Um ihn wieder hier zu verbinden:\n\n1. Gehe zu Einstellungen → Bluetooth\n2. Tippe auf das (i) neben dem Calliope mini\n3. Wähle \"Dieses Gerät ignorieren\"\n4. Kehre zur Calliope mini App zurück und verbinde erneut", comment: "Instructions to reset Bluetooth pairing"),
                preferredStyle: .alert
            )

            // Button der zu den System-Einstellungen führt (öffnet generelle iOS Einstellungen)
            // WICHTIG: iOS erlaubt nur das Öffnen der allgemeinen Einstellungen,
            // nicht direkt der Bluetooth-Einstellungen
            alertController?.addAction(UIAlertAction(
                title: NSLocalizedString("Einstellungen öffnen", comment: "Open Settings"),
                style: .default,
                handler: { _ in
                    // Öffnet die iOS Einstellungen (nicht App-Einstellungen!)
                    // Der Benutzer kann dann manuell zu Bluetooth navigieren
                    if let url = URL(string: "App-prefs:root=Bluetooth") {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            ))
        } else if error.localizedDescription == NSLocalizedString("Connection to calliope timed out!", comment: "") {
            // Timeout ignorieren wenn noch nie verbunden war
            if !hasEverConnected {
                LogNotify.log("Ignoring connection timeout - never connected before")
                alertController = nil
            } else {
                alertController = nil  // Auch bei vorheriger Verbindung ignorieren (wie bisher)
            }
        } else if error.localizedDescription.contains("Calliope mini") && !hasEverConnected {
            // Andere Calliope-bezogene Fehler nur anzeigen wenn schon mal verbunden war
            LogNotify.log("Ignoring error - never connected before: \(error.localizedDescription)")
            alertController = nil
        } else {
            // TEMP: Alert deaktiviert - kann später wieder aktiviert werden
            // alertController = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: NSLocalizedString("Encountered an error discovering or connecting calliope:", comment: "") + "\n\(error.localizedDescription)", preferredStyle: .alert)
            LogNotify.log("Error suppressed (alert commented out): \(error.localizedDescription)")
            alertController = nil
        }

        guard let alertController = alertController else {
            return
        }

        // Falls es sich um die Standard-Fehlermeldung handelt, die nur einmal gezeigt werden soll,
        // die Variable setzen
        if alertController.title == NSLocalizedString("Error", comment: "") {
            isShowingErrorAlert = true
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.isShowingErrorAlert = false
            }))
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default))
        }

        self.show(alertController, sender: nil)
    }
    }
