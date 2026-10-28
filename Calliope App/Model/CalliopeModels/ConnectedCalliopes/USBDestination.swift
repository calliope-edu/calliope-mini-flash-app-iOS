//
//  USBDestination.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol USBDestinationPicker: AnyObject {
    // Exports contents to a file the user picks; a nil result means the user cancelled.
    func pickDestination(filename: String, contents: Data, completion: @escaping (Result<URL, Error>?) -> Void)
}

extension USBDestinationPicker {
    func pickDestination(filename: String, completion: @escaping (Result<URL, Error>?) -> Void) {
        pickDestination(filename: filename, contents: Data(), completion: completion)
    }
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
