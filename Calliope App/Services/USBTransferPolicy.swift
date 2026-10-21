//
//  USBTransferPolicy.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import UIKit

struct USBTransferPolicy {
    let isSharedIPad: Bool
    let picksDestinationPerFlash: Bool

    init(isSharedIPad: Bool, systemMajorVersion: Int) {
        self.isSharedIPad = isSharedIPad
        // Shared iPad silently refuses folder picks of USB volumes; below iPadOS 26 the picker cannot confirm a volume.
        picksDestinationPerFlash = isSharedIPad || systemMajorVersion < 26
    }

    // A cancelled copy may leave the picked volume unusable, so the user has to pick it again.
    var dropsConnectionAfterCancelledCopy: Bool {
        picksDestinationPerFlash
    }

    // Without a folder there is no device to connect to before the first flash.
    var allowsUploadWithoutDevice: Bool {
        picksDestinationPerFlash
    }

    static var current: USBTransferPolicy {
        USBTransferPolicy(
            isSharedIPad: UIDevice.current.isSharedIPad,
            systemMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }
}
