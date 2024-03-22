//
//  BlinkingHeartProgram.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.12.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

class DefaultProgramV1andV2: DownloadableHexFile {
    static var blinkingHeartProgram: DefaultProgramV1andV2 = DefaultProgramV1andV2()
    
    let loadableProgramName = "Calliope mini 1+2"
    let loadableProgramURL = UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue)!
    
    lazy var downloadedHexFile: HexFile? = storedHexFileInitializer()
    
    private init() {}
}
