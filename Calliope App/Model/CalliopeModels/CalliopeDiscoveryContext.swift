//
//  CalliopeDiscoveryContext.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol CalliopeDiscoveryContext: AnyObject {
    var isInUsbMode: Bool { get }
    var isConnectionEnabled: Bool { get }
    func showFalseLocationAlert()
}
