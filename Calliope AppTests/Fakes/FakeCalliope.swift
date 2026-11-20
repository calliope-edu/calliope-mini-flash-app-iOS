//
//  FakeCalliope.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import NordicDFU
@testable import Calliope_App

// Holds its delegates strongly (the real devices hold them weakly), so late callbacks really reach a finished job.
final class FakeCalliope: Calliope {
    var supportedHexTypes: Set<HexParser.HexVersion> = [.v3]
    private(set) var cancelCount = 0

    private var progressReceiver: DFUProgressDelegate?
    private var statusDelegate: DFUServiceDelegate?

    override var compatibleHexTypes: Set<HexParser.HexVersion> {
        supportedHexTypes
    }

    override func upload(file: Hex, progressReceiver: DFUProgressDelegate? = nil, statusDelegate: DFUServiceDelegate? = nil, logReceiver: LoggerDelegate? = nil) throws {
        self.progressReceiver = progressReceiver
        self.statusDelegate = statusDelegate
    }

    override func cancelUpload() -> Bool {
        cancelCount += 1
        return true
    }

    func reportProgress(_ percent: Int) {
        progressReceiver?.dfuProgressDidChange(for: 1, outOf: 1, to: percent, currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0)
    }

    func reportState(_ state: DFUState) {
        statusDelegate?.dfuStateDidChange(to: state)
    }

    func reportError(_ message: String) {
        statusDelegate?.dfuError(.deviceDisconnected, didOccurWithMessage: message)
    }
}
