//
//  USBTransferStrategy.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

enum USBTransferOutcome {
    case written
    case failed
    case cancelledByUser
}

protocol USBTransferStrategy {
    var isConnected: Bool { get }
    // Called on the main queue; onRejected can follow a .written outcome once DAPLink has checked the hex.
    func transfer(_ source: URL, named name: String, onRejected: @escaping (String) -> Void, completion: @escaping (USBTransferOutcome) -> Void)
}
