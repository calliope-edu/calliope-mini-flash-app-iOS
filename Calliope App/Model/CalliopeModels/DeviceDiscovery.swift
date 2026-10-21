//
//  DeviceDiscovery.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import CoreBluetooth
import Foundation

protocol DeviceDiscovery: AnyObject {
    typealias Factory = (
        _ calliopeBuilder: @escaping (_ peripheral: CBPeripheral, _ name: String) -> DiscoveredBLEDevice,
        _ context: CalliopeDiscoveryContext?
    ) -> DeviceDiscovery

    var state: CalliopeDiscovery.CalliopeDiscoveryState { get }
    var discoveredCalliopes: [String: DiscoveredDevice] { get }
    var connectedBLEDevice: DiscoveredDevice? { get }
    var connectedUSBDevice: DiscoveredDevice? { get }
    var updateBlock: () -> Void { get set }
    var errorBlock: (Error) -> Void { get set }
    var bluetoothStateChangedBlock: (CBManagerState) -> Void { get set }
    var isInBackground: Bool { get set }
    var context: CalliopeDiscoveryContext? { get set }

    func startCalliopeDiscovery()
    func stopCalliopeDiscovery()
    func connectToCalliope(_ calliope: DiscoveredDevice)
    func disconnectFromCalliope()
    func disconnectForReboot()
    func giveUpResponsibility()
    func startUsbConnect()
    func connectUsbCalliope(to destination: USBDestination)
    func registerDisconnectNotification(_ callback: @escaping (String) -> Void) -> Int
}

extension CalliopeDiscovery: DeviceDiscovery {
    var connectedBLEDevice: DiscoveredDevice? { connectedCalliope }
    var connectedUSBDevice: DiscoveredDevice? { connectedUSBCalliope }
}
