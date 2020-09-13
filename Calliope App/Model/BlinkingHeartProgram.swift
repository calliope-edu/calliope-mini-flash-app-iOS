//
//  BlinkingHeartProgram.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.12.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

class BlinkingHeartProgram: DownloadableHexFile {
    static var blinkingHeartProgram: BlinkingHeartProgram = BlinkingHeartProgram()
    
    let loadableProgramName = "Blinking Heart"
    let loadableProgramURL = UserDefaults.standard.string(forKey: SettingsKey.blinkingHeartURL.rawValue)!
    
    lazy var downloadedHexFile: HexFile? = storedHexFileInitializer()
    
    private init() {}
}
