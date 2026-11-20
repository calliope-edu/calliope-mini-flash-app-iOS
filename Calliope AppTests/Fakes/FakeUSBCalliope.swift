//
//  FakeUSBCalliope.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import NordicDFU
@testable import Calliope_App

final class FakeUSBCalliope: USBCalliope {
    private var statusDelegate: DFUServiceDelegate?

    init() {
        super.init(destination: .folder(URL(fileURLWithPath: "/dev/null")))
        // The USBCalliope initializer flags a connection switch, which would suppress errors in the test.
        Calliope.isConnectionSwitching = false
    }

    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        [.v3]
    }

    override func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        self.statusDelegate = statusDelegate
    }

    func reportState(_ state: DFUState) {
        statusDelegate?.dfuStateDidChange(to: state)
    }

    func reportRejection(_ reason: String) {
        onTransferRejected?(reason)
    }
}
