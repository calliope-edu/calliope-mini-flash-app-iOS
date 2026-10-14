//
//  FakeHex.swift
//  Calliope AppTests
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
@testable import Calliope_App

struct FakeHex: Hex {
    var hexTypes: Set<HexParser.HexVersion> = [.v3]

    let name = "Test program"
    let date = Date()
    let calliopeV1andV2Bin = Data()
    let calliopeV3Bin = Data()
    let calliopeUSBUrl = URL(fileURLWithPath: "/dev/null")
    let calliopeArcadeBin = Data()
    let partialFlashingInfo: (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? = nil

    func getHexTypes() -> Set<HexParser.HexVersion> {
        hexTypes
    }
}
