//
//  CalliopeBLEDiscovery.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 08.12.18.
//

import CoreBluetooth
import UIKit
import UniformTypeIdentifiers

class CalliopeDiscovery: NSObject, CBCentralManagerDelegate, UIDocumentPickerDelegate {

    enum CalliopeDiscoveryState {
        case initialized  //no discovered calliopes, doing nothing
        case discoveryWaitingForBluetooth  //invoked discovery but waiting for the system bluetooth (might be off)
        case discovering  //running the discovery process now, but not discovered anything yet
        case discovered  //discovery list is not empty, still searching
        case discoveredAll  //discovery has finished with discovered calliopes
        case connecting  //connecting to some calliope
        case connected  //connected to some calliope
        case usbConnecting  // connecting to a usb calliope
        case usbConnected  // connected to a usb calliope
    }

    private static let usbCalliopeName = "USB_CALLIOPE"

    var updateQueue = DispatchQueue.main
    var updateBlock: () -> Void = {
    }
    var errorBlock: (Error) -> Void = { _ in
    }

    var calliopeBuilder: (_ peripheral: CBPeripheral, _ name: String) -> DiscoveredBLEDDevice

    private(set) var state: CalliopeDiscoveryState = .initialized {
        didSet {
            LogNotify.log("Calliope mini discovery state: \(state)")
            updateQueue.async {
                self.updateBlock()
            }
        }
    }

    private(set) var discoveredCalliopes: [String: DiscoveredDevice] = [:] {
        didSet {
            LogNotify.log("discovered: \(discoveredCalliopes)")
            redetermineState()
        }
    }

    private var discoveredCalliopeUUIDNameMap: [UUID: String] = [:]

    private(set) var connectingCalliope: DiscoveredDevice? {
        didSet {
            if let connectingCalliope = self.connectingCalliope {
                if connectingCalliope is DiscoveredBLEDDevice {
                    LogNotify.log("Connect to Bluetooth Calliope mini")
                    let connectingBLECalliope = connectingCalliope as! DiscoveredBLEDDevice
                    connectedCalliope = nil
                    self.centralManager.connect(connectingBLECalliope.peripheral, options: nil)
                    //manual timeout (system timeout is too long)
                    bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + .seconds(BluetoothConstants.connectTimeout)) {
                        if self.connectedCalliope == nil && self.connectingCalliope === connectingCalliope {
                            LogNotify.log("Connection attempt timed out for \(connectingCalliope)")
                            self.centralManager.cancelPeripheralConnection(connectingBLECalliope.peripheral)
                            // NEU: Bei Timeout während Reconnect nach DFU, erneut versuchen
                            if self.isWaitingForDFUReconnect {
                                self.handleDFUReconnectTimeout(connectingBLECalliope)
                            } else {
                                self.updateQueue.async {
                                    self.errorBlock(NSLocalizedString("Connection to Calliope mini timed out!", comment: ""))
                                }
                            }
                        }
                    }
                }
                if connectingCalliope is DiscoveredUSBDevice {
                    LogNotify.log("Connect to USB Calliope mini")
                    let connectingUSBCalliope = connectingCalliope as! DiscoveredUSBDevice
                    do {
                        connectedUSBCalliope = connectingUSBCalliope
                        connectedUSBCalliope?.usageReadyCalliope = try USBCalliope(calliopeLocation: connectingUSBCalliope.url)
                        dispatchUSBCalliopePolling()
                        LogNotify.log("Calliope mini Discovery State now: \(state)")
                    } catch {
                        LogNotify.log("Connecting to USB Calliope mini failed")
                    }

                }

            }
            redetermineState()
        }
    }

    private(set) var connectedCalliope: DiscoveredBLEDDevice? {
        didSet {
            if let uuid = connectedCalliope?.peripheral.identifier,
                let name = discoveredCalliopeUUIDNameMap[uuid]
            {
                lastConnected = (uuid, name)
            }
            oldValue?.hasDisconnected()
            connectedCalliope?.hasConnected()
            if connectedCalliope != nil {
                connectingCalliope = nil
                // NEU: DFU Reconnect erfolgreich
                if isWaitingForDFUReconnect {
                    LogNotify.log("DFU reconnect successful!")
                    isWaitingForDFUReconnect = false
                    dfuReconnectAttempts = 0
                }
            }
            redetermineState()
        }
    }

    private(set) var connectedUSBCalliope: DiscoveredUSBDevice? {
        didSet {
            oldValue?.hasDisconnected()
            connectedUSBCalliope?.hasConnected()
            connectedUSBCalliope?.state = .usageReady
            if connectedUSBCalliope != nil {
                connectingCalliope = nil
            }
            redetermineState()
        }
    }

    private let bluetoothQueue = DispatchQueue.global(qos: .userInitiated)
    private lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: nil, queue: bluetoothQueue)
    }()

    private var lastConnected: (UUID, String)? {
        get {
            let defaults = UserDefaults.standard
            guard let dict = defaults.dictionary(forKey: BluetoothConstants.lastConnectedKey),
                let name = dict[BluetoothConstants.lastConnectedNameKey] as? String,
                let uuidString = dict[BluetoothConstants.lastConnectedUUIDKey] as? String,
                let uuid = UUID(uuidString: uuidString)
            else {
                return nil
            }
            return (uuid, name)
        }
        set {
            let defaults = UserDefaults.standard
            guard let newUUIDString = newValue?.0.uuidString,
                let newName = newValue?.1
            else {
                defaults.removeObject(forKey: BluetoothConstants.lastConnectedKey)
                return
            }
            defaults.setValue(
                [
                    BluetoothConstants.lastConnectedNameKey: newName,
                    BluetoothConstants.lastConnectedUUIDKey: newUUIDString,
                ],
                forKey: BluetoothConstants.lastConnectedKey)
        }
    }

    private var retryCount = 0
    public var isInBackground = false
    
    // NEU: DFU Reconnect Tracking
    private var isWaitingForDFUReconnect = false
    private var dfuReconnectAttempts = 0
    private let maxDFUReconnectAttempts = 5
    private var lastDFUDisconnectedCalliope: DiscoveredBLEDDevice?

    init(_ calliopeBuilder: @escaping (_ peripheral: CBPeripheral, _ name: String) -> DiscoveredBLEDDevice) {
        self.calliopeBuilder = calliopeBuilder
        super.init()
        if centralManager.state == .poweredOn {
            attemptReconnect()
        }
        centralManager.delegate = self
    }

    private func redetermineState() {
        if connectedCalliope != nil {
            state = .connected
        } else if connectedUSBCalliope != nil {
            state = .usbConnected
        } else if connectingCalliope != nil {
            state = .connecting
        } else if centralManager.isScanning && MatrixConnectionViewController.instance != nil && !MatrixConnectionViewController.instance.isInUsbMode {
            state = discoveredCalliopes.isEmpty ? .discovering : .discovered
        } else {
            state = discoveredCalliopes.isEmpty ? .initialized : .discoveredAll
        }
    }

    private func attemptReconnect() {
        LogNotify.log("attempt reconnect")
        guard let (lastConnectedUUID, lastConnectedName) = self.lastConnected,
            let lastCalliope = centralManager.retrievePeripherals(withIdentifiers: [lastConnectedUUID]).first
        else {
            return
        }

        let calliope = calliopeBuilder(lastCalliope, lastConnectedName)

        self.discoveredCalliopes.updateValue(calliope, forKey: lastConnectedName)
        self.discoveredCalliopeUUIDNameMap.updateValue(lastConnectedName, forKey: lastCalliope.identifier)
        //auto-reconnect
        LogNotify.log("reconnect to: \(calliope)")
        delay(time: 0) {
            self.connectingCalliope = calliope
        }
    }


    /// allows another CalliopeBLEDiscovery to use lastConnected variable to reconnect to the same calliope
    public func giveUpResponsibility() {
        self.updateBlock = {
        }
        self.stopCalliopeDiscovery()
        //we disconnect manually here after switching off delegate, since we don´t want to wipe lastconnected setting
        centralManager.delegate = nil
        if let connectedCalliope = self.connectedCalliope {
            self.centralManager.cancelPeripheralConnection(connectedCalliope.peripheral)
        }
    }

    // MARK: discovery

    func startCalliopeDiscovery() {
        //start scan only if central manger already connected to bluetooth system service (=poweredOn)
        //alternatively, this is invoked after the state of the central mananger changed to poweredOn.
        if centralManager.state != .poweredOn {
            if !MatrixConnectionViewController.instance.isInUsbMode {
                updateQueue.async {
                    self.errorBlock(NSLocalizedString("Activate Bluetooth!", comment: ""))
                }
                state = .discoveryWaitingForBluetooth
            }
        } else if !centralManager.isScanning {
            if MatrixConnectionViewController.instance.isInUsbMode, let discoveredCalliope = discoveredCalliopes[CalliopeDiscovery.usbCalliopeName] {
                discoveredCalliopes = [ CalliopeDiscovery.usbCalliopeName : discoveredCalliope ]
            } else {
                discoveredCalliopes = [:]
            }
            discoveredCalliopeUUIDNameMap = [:]
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            //stop the search after some time. The user can invoke it again later.
            bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.discoveryTimeout) {
                // NEU: Nicht stoppen wenn wir auf DFU Reconnect warten
                if !self.isWaitingForDFUReconnect {
                    self.stopCalliopeDiscovery()
                }
            }
            redetermineState()
        }
    }

    func retryCalliopeDiscovery(_ targetCalliope: DiscoveredDevice) {
        if isInBackground || self.connectedCalliope != nil || self.retryCount >= BluetoothConstants.maxRetryCount {
            LogNotify.log("Stopping retrying due to: isInBackground \(isInBackground) - retrycount (current: \(retryCount), max: \(BluetoothConstants.maxRetryCount)) - connected - \(connectedCalliope != nil)")
            retryCount = 0
            return
        }

        self.retryCount += 1
        LogNotify.log("Trying reconnection \(retryCount)/\(BluetoothConstants.maxRetryCount)")
        self.connectToCalliope(targetCalliope)

        bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + .seconds(BluetoothConstants.retryDelay)) {
            self.retryCalliopeDiscovery(targetCalliope)
        }
    }

    func stopCalliopeDiscovery() {
        if centralManager.isScanning {
            self.centralManager.stopScan()
        }
        redetermineState()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber,
            connectable.boolValue == true,
            let localName = advertisementData[CBAdvertisementDataLocalNameKey],
            let lowerName = (localName as? String)?.lowercased(),
            BluetoothConstants.deviceNames.map({ lowerName.contains($0) }).contains(true),
            let friendlyName = Matrix.full2Friendly(fullName: lowerName)
        {
            //never create a calliope twice, since this would clear its state
            if discoveredCalliopes[friendlyName] == nil {
                //we found a calliope device (or one that pretends to be a calliope at least)
                let calliope = calliopeBuilder(peripheral, friendlyName)
                discoveredCalliopes.updateValue(calliope, forKey: friendlyName)
                discoveredCalliopeUUIDNameMap.updateValue(friendlyName, forKey: peripheral.identifier)
                
                // NEU: Wenn wir auf DFU Reconnect warten und den Calliope wiederfinden
                if isWaitingForDFUReconnect, let lastDFU = lastDFUDisconnectedCalliope {
                    // Prüfe ob es derselbe Calliope ist (gleicher Name)
                    if friendlyName == lastDFU.name {
                        LogNotify.log("Found Calliope after DFU, attempting reconnect: \(friendlyName)")
                        connectToCalliope(calliope)
                    }
                }
            }
        }
    }

    // MARK: connection

    func connectToCalliope(_ calliope: DiscoveredDevice) {
        // NEU: Bei DFU Reconnect Discovery nicht stoppen
        if !isWaitingForDFUReconnect {
            stopCalliopeDiscovery()
        }
        
        guard calliope != connectedCalliope else {
            return
        }
        
        // NEU: Bei DFU Reconnect lastConnected nicht löschen
        if !isWaitingForDFUReconnect {
            lastConnected = nil
        }
        
        connectingCalliope = calliope
    }

    func disconnectFromCalliope() {
        if let connectedCalliope = self.connectedCalliope {
            self.centralManager.cancelPeripheralConnection(connectedCalliope.peripheral)
        }
        if connectedUSBCalliope != nil {
            discoveredCalliopes.removeValue(forKey: CalliopeDiscovery.usbCalliopeName)
        }
        self.connectedUSBCalliope = nil
        self.connectedCalliope = nil
    }

    func initializeConnectionToUsbCalliope(view: UIViewController) {
        state = .usbConnecting
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        view.present(documentPicker, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let url = urls.first
        let discoveredCalliope = DiscoveredUSBDevice(url: url!, name: CalliopeDiscovery.usbCalliopeName)
        
        guard let discoveredCalliope = discoveredCalliope else {
            MatrixConnectionViewController.instance.showFalseLocationAlert()
            state = .initialized
            return
        }
        
        disconnectFromCalliope()
        discoveredCalliope.state = DiscoveredDevice.CalliopeBLEDeviceState.discovered
        self.discoveredCalliopes.updateValue(discoveredCalliope, forKey: CalliopeDiscovery.usbCalliopeName)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let name = discoveredCalliopeUUIDNameMap[peripheral.identifier],
            let calliope = discoveredCalliopes[name]
        else {
            updateQueue.async {
                self.errorBlock(NSLocalizedString("Could not find connected Calliope mini in discovered Calliope minis", comment: ""))
            }
            return
        }
        connectedCalliope = calliope as? DiscoveredBLEDDevice
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        LogNotify.log("disconnected from \(peripheral.name ?? "unknown device"), with error: \(error?.localizedDescription ?? "none")")
        
        guard let disconnectedCalliope = connectedCalliope else {
            connectedCalliope = nil
            connectingCalliope = nil
            return
        }
        
        let shouldReconnect = disconnectedCalliope.shouldReconnectAfterReboot()
        let isDFURelated = disconnectedCalliope.usageReadyCalliope?.rebootingIntoDFUMode ?? false
        
        LogNotify.log("Disconnect analysis: shouldReconnect=\(shouldReconnect), isDFURelated=\(isDFURelated), isInBackground=\(isInBackground)")
        
        // Fall 1: Calliope soll nach Reboot reconnecten (DFU oder Partial Flashing Reboot)
        if shouldReconnect {
            LogNotify.log("Calliope requested reconnect after reboot - starting reconnect process")
            disconnectedCalliope.rebootingCalliope = disconnectedCalliope.usageReadyCalliope
            self.connectedCalliope = nil
            isWaitingForDFUReconnect = true
            dfuReconnectAttempts = 0
            
            // Warte auf Neustart (V3 braucht etwas länger)
            let restartDelay = 3.0  // Etwas länger als standard restartDuration
            bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + restartDelay) {
                self.attemptDFUReconnect(disconnectedCalliope)
            }
            return
        }
        
        // Fall 2: Unerwartete Trennung während wir nicht im Hintergrund sind
        if !isInBackground {
            self.connectedCalliope = nil
            connectingCalliope = nil
            // lastConnected NICHT löschen - ermöglicht manuellen Reconnect
            self.retryCalliopeDiscovery(disconnectedCalliope)
            return
        }
        
        // Fall 3: App im Hintergrund
        connectedCalliope = nil
        connectingCalliope = nil
        lastConnected = nil
    }
    
    // NEU: Prüfe ob der Fehler ein erwarteter DFU-Disconnect ist
    private func isExpectedDFUDisconnect(_ error: Error?) -> Bool {
        // Nordic DFU trennt die Verbindung nach erfolgreichem Flash
        // Dies kann verschiedene Fehlercodes haben oder keinen Fehler
        guard let error = error as NSError? else {
            // Kein Fehler kann auch DFU-bedingt sein
            return false
        }
        
        // CBError Codes die bei DFU auftreten können:
        // - connectionTimeout (6)
        // - peripheralDisconnected (7)
        let dfuRelatedCodes = [6, 7]
        return dfuRelatedCodes.contains(error.code)
    }
    
    // NEU: Starte den DFU Reconnect Prozess
    private func startDFUReconnect(_ calliope: DiscoveredBLEDDevice) {
        LogNotify.log("Starting DFU reconnect process for \(calliope.name)")
        
        isWaitingForDFUReconnect = true
        dfuReconnectAttempts = 0
        lastDFUDisconnectedCalliope = calliope
        
        // Speichere den Calliope für späteren Reconnect
        calliope.rebootingCalliope = calliope.usageReadyCalliope
        self.connectedCalliope = nil
        
        // Warte länger auf den Neustart nach DFU (Calliope V3 braucht mehr Zeit)
        let dfuRestartDuration = 4.0  // Länger als normaler restartDuration
        
        bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + dfuRestartDuration) {
            self.attemptDFUReconnect(calliope)
        }
    }
    
    // NEU: Versuche Reconnect nach DFU
    private func attemptDFUReconnect(_ calliope: DiscoveredBLEDDevice) {
        guard isWaitingForDFUReconnect else {
            LogNotify.log("DFU reconnect cancelled")
            return
        }
        
        // Prüfe ob wir bereits verbunden sind
        if connectedCalliope != nil {
            LogNotify.log("DFU reconnect successful - already connected")
            isWaitingForDFUReconnect = false
            dfuReconnectAttempts = 0
            return
        }
        
        dfuReconnectAttempts += 1
        LogNotify.log("DFU reconnect attempt \(dfuReconnectAttempts)/\(maxDFUReconnectAttempts)")
        
        if dfuReconnectAttempts > maxDFUReconnectAttempts {
            LogNotify.log("DFU reconnect failed after \(maxDFUReconnectAttempts) attempts")
            isWaitingForDFUReconnect = false
            // Nicht als Fehler melden - Calliope läuft, nur nicht verbunden
            // Nutzer kann manuell neu verbinden
            return
        }
        
        // Versuche direkt zu verbinden
        connectToCalliope(calliope)
        
        // Plane nächsten Versuch falls dieser fehlschlägt
        bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + 3.0) {
            if self.isWaitingForDFUReconnect && self.connectedCalliope == nil {
                self.attemptDFUReconnect(calliope)
            }
        }
    }
    
    // NEU: Handle Timeout während DFU Reconnect
    private func handleDFUReconnectTimeout(_ calliope: DiscoveredBLEDDevice) {
        LogNotify.log("DFU reconnect connection attempt timed out")
        connectingCalliope = nil
        
        // Versuche erneut
        if dfuReconnectAttempts < maxDFUReconnectAttempts {
            bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + 2.0) {
                if let lastDFU = self.lastDFUDisconnectedCalliope {
                    self.attemptDFUReconnect(lastDFU)
                }
            }
        } else {
            isWaitingForDFUReconnect = false
            lastDFUDisconnectedCalliope = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        LogNotify.log("Failed to connect to \(peripheral.name ?? "unknown"): \(error?.localizedDescription ?? "unknown error")")
        
        // NEU: Bei DFU Reconnect nicht sofort aufgeben
        if isWaitingForDFUReconnect {
            if let lastDFU = lastDFUDisconnectedCalliope {
                handleDFUReconnectTimeout(lastDFU)
            }
            return
        }
        
        if let error = error {
            updateQueue.async {
                self.errorBlock(error)
            }
        }
        connectingCalliope = nil
    }

    // MARK: state of the bluetooth manager

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startCalliopeDiscovery()
            if lastConnected != nil {
                self.attemptReconnect()
            }
        case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
            if state == .usbConnected || state == .usbConnecting {
                return
            }
            //bluetooth is in a state where we cannot do anything
            connectingCalliope = nil
            connectedCalliope = nil
            discoveredCalliopes = [:]
            discoveredCalliopeUUIDNameMap = [:]
            isWaitingForDFUReconnect = false  // NEU: Reset DFU state
            state = .initialized
        @unknown default:
            break
        }
    }

    // MARK: Delegate for keeping an eye on USB connection
    
    private let MAX_RETRIES = 3
    private let POLLING_RATE_IN_SEC: Double = 0.5
    private let DELAY: Double = 15
    
    private var backoff: Bool = false // e.g. current writes to calliope
    private var currentRetries = 0

    private func dispatchUSBCalliopePolling(_ delay: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + POLLING_RATE_IN_SEC + (backoff ? DELAY : 0)) {
            self.backoff = delay
            guard let connectedUSBCalliope = self.connectedUSBCalliope, let usbCalliope = connectedUSBCalliope.usageReadyCalliope as? USBCalliope?, let usbCalliope = usbCalliope else {
                return
            }

            if usbCalliope.isConnected() || usbCalliope.writeInProgress || self.isInBackground {
                if self.currentRetries > 0 {
                    LogNotify.log("USB Calliope mini reachable after \(self.currentRetries) retries: (\(usbCalliope.isConnected()), \(usbCalliope.writeInProgress), \(self.isInBackground), \(self.backoff))")
                    self.currentRetries = 0
                }
                self.dispatchUSBCalliopePolling(usbCalliope.writeInProgress)
                return
            }
          
            LogNotify.log("USB Calliope mini not reachable (\(usbCalliope.isConnected()), \(usbCalliope.writeInProgress), \(self.isInBackground), \(self.backoff)), \(self.currentRetries < self.MAX_RETRIES ? "retrying" : "disconnecting")")
            if self.currentRetries < self.MAX_RETRIES {
                self.currentRetries += 1
                self.dispatchUSBCalliopePolling()
                return
            }
            
            self.currentRetries = 0
            self.disconnectFromCalliope()

        }
    }

}
