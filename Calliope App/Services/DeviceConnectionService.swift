//
//  DeviceConnectionService.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol DeviceConnectionService: AnyObject {
    var currentCalliope: Calliope? { get }

    func setDfuMode(_ enabled: Bool)
    func disconnectForReboot()
    func resetUsbConnectionAfterCopy()
}
