//
//  USBTransferPolicy.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

struct USBTransferPolicy {
    let isSharedIPad: Bool
    let picksDestinationPerFlash: Bool

    init(isSharedIPad: Bool, systemMajorVersion: Int) {
        self.isSharedIPad = isSharedIPad
        // Shared iPad silently refuses folder picks of USB volumes; below iPadOS 26 the picker cannot confirm a volume.
        picksDestinationPerFlash = isSharedIPad || systemMajorVersion < 26
    }

    // Without a folder there is no device to connect to before the first flash.
    var allowsUploadWithoutDevice: Bool {
        picksDestinationPerFlash
    }
}
