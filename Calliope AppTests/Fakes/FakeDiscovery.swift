//
//  FakeDiscovery.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import CoreBluetooth
import Foundation
@testable import Calliope_App

// Records commands without changing state; tests drive state explicitly and get updateBlock synchronously.
final class FakeDiscovery: DeviceDiscovery {
    private(set) var state: CalliopeDiscovery.CalliopeDiscoveryState = .initialized
    private(set) var discoveredCalliopes: [String: DiscoveredDevice] = [:]
    private(set) var connectedBLEDevice: DiscoveredDevice?
    private(set) var connectedUSBDevice: DiscoveredDevice?
    var updateBlock: () -> Void = {}
    var errorBlock: (Error) -> Void = { _ in }
    var bluetoothStateChangedBlock: (CBManagerState) -> Void = { _ in }
    var isInBackground = false
    weak var context: CalliopeDiscoveryContext?

    private(set) var connectRequests: [DiscoveredDevice] = []
    private(set) var usbDestinations: [USBDestination] = []
    private(set) var startDiscoveryCount = 0
    private(set) var stopDiscoveryCount = 0
    private(set) var disconnectCount = 0
    private(set) var gaveUpResponsibility = false
    private var disconnectCallbacks: [(String) -> Void] = []

    init(context: CalliopeDiscoveryContext?) {
        self.context = context
    }

    // MARK: - Driving the fake

    func discover(_ devices: DiscoveredDevice..., state: CalliopeDiscovery.CalliopeDiscoveryState = .discovered) {
        for device in devices {
            discoveredCalliopes[device.name] = device
        }
        setState(state)
    }

    func connectBLE(_ device: DiscoveredDevice) {
        discoveredCalliopes[device.name] = device
        connectedBLEDevice = device
        setState(.connected)
    }

    func connectUSB(_ device: DiscoveredUSBDevice) {
        discoveredCalliopes[device.name] = device
        connectedUSBDevice = device
        device.state = .usageReady
        setState(.usbConnected)
    }

    func setState(_ newState: CalliopeDiscovery.CalliopeDiscoveryState) {
        state = newState
        updateBlock()
    }

    func reportDisconnect(uuid: String) {
        disconnectCallbacks.forEach { $0(uuid) }
    }

    // MARK: - DeviceDiscovery

    func startCalliopeDiscovery() {
        startDiscoveryCount += 1
    }

    func stopCalliopeDiscovery() {
        stopDiscoveryCount += 1
    }

    func connectToCalliope(_ calliope: DiscoveredDevice) {
        connectRequests.append(calliope)
    }

    func disconnectFromCalliope() {
        disconnectCount += 1
        if let usbDevice = connectedUSBDevice {
            discoveredCalliopes.removeValue(forKey: usbDevice.name)
        }
        connectedBLEDevice = nil
        connectedUSBDevice = nil
    }

    func disconnectForReboot() {}

    func giveUpResponsibility() {
        gaveUpResponsibility = true
    }

    func startUsbConnect() {}

    func connectUsbCalliope(to destination: USBDestination) {
        usbDestinations.append(destination)
    }

    func registerDisconnectNotification(_ callback: @escaping (String) -> Void) -> Int {
        disconnectCallbacks.append(callback)
        return disconnectCallbacks.count - 1
    }
}
