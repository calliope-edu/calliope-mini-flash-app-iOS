//
//  CentralManaging.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import CoreBluetooth
import Foundation

protocol CentralManaging: AnyObject {
    var state: CBManagerState { get }
    var isScanning: Bool { get }
    var delegate: CBCentralManagerDelegate? { get set }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
    func connect(_ peripheral: CBPeripheral, options: [String: Any]?)
    func cancelPeripheralConnection(_ peripheral: CBPeripheral)
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral]
}

extension CBCentralManager: CentralManaging {}
