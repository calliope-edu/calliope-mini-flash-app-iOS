//
//  FakeDeviceConnection.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import Foundation
@testable import Calliope_App

final class FakeDeviceConnection: DeviceConnectionService {
    var currentCalliope: Calliope?

    private let lostSubject = PassthroughSubject<Void, Never>()
    var connectionLost: AnyPublisher<Void, Never> {
        lostSubject.eraseToAnyPublisher()
    }

    func loseConnection() {
        lostSubject.send()
    }

    var bleCalliope: Calliope?
    var isUsbMode = false
    var isUsbConnected = false
    var isBluetoothAvailable = true
    var deviceDisconnected: AnyPublisher<String, Never> {
        Empty().eraseToAnyPublisher()
    }

    func start() {}
    func enterForeground() {}
    func enterBackground() {}
    func suspendBluetooth() {}
    func resumeBluetooth() {}
    func reconnect(preferredName: String?) {}
    func setDfuMode(_ enabled: Bool) {}
    func disconnectForReboot() {}
    func resetUsbConnectionAfterCopy() {}
}
