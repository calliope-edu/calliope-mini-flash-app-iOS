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

    func setDfuMode(_ enabled: Bool) {}
    func disconnectForReboot() {}
    func resetUsbConnectionAfterCopy() {}
}
