//
//  FakeUSBDestinationPicker.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
@testable import Calliope_App

final class FakeUSBDestinationPicker: USBDestinationPicker {
    // nil means the user cancels.
    var result: Result<URL, Error>?
    // Keeps the picker "on screen" instead of answering.
    var staysOpen = false
    var onRequest: (() -> Void)?
    private(set) var requestedFilenames: [String] = []

    func pickDestination(filename: String, completion: @escaping (Result<URL, Error>?) -> Void) {
        requestedFilenames.append(filename)
        onRequest?()
        if !staysOpen {
            completion(result)
        }
    }
}
