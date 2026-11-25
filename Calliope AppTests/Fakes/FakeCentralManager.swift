//
//  FakeCentralManager.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import CoreBluetooth
import Foundation
@testable import Calliope_App

final class FakeCentralManager: CentralManaging {
    var state: CBManagerState = .poweredOff
    private(set) var isScanning = false
    weak var delegate: CBCentralManagerDelegate?

    private(set) var scanCount = 0
    private(set) var stopScanCount = 0

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        scanCount += 1
        isScanning = true
    }

    func stopScan() {
        stopScanCount += 1
        isScanning = false
    }

    func connect(_ peripheral: CBPeripheral, options: [String: Any]?) {}

    func cancelPeripheralConnection(_ peripheral: CBPeripheral) {}

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        []
    }
}
