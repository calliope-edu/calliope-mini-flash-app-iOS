//
//  FakeDiscoveredDevice.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
@testable import Calliope_App

// A BLE device needs a real CBPeripheral, so BLE devices are faked on the common base class.
final class FakeDiscoveredDevice: DiscoveredDevice {
    // The real one starts a service discovery, which would move the device on by itself.
    override func evaluateMode() {}
}
