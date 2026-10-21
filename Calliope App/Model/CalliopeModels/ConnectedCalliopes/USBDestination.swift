//
//  USBDestination.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol USBDestinationPicker: AnyObject {
    // A nil result means the user cancelled.
    func pickDestination(filename: String, completion: @escaping (Result<URL, Error>?) -> Void)
}

enum USBDestination {
    case folder(URL)
    case pickPerFlash(USBDestinationPicker)

    var picksPerFlash: Bool {
        if case .pickPerFlash = self {
            return true
        }
        return false
    }
}
