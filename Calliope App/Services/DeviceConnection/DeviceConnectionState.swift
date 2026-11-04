//
//  DeviceConnectionState.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import CoreBluetooth
import Foundation

enum DeviceConnectionState: Equatable {
    case idle
    case waitingForBluetooth
    case searching
    case notFound
    case connecting
    case transmitting
    case usbConnecting
    case readyToConnect(rebooting: Bool)
    case preparing
    case ready
    case wrongProgram
}

enum DeviceConnectionEvent {
    case bluetoothStateChanged(CBManagerState)
    case pairingRemoved
    case invalidUsbLocation
}
