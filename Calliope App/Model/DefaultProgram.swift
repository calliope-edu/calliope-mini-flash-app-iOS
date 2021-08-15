//
//  DefaultProgram.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.11.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

class DefaultProgram: DownloadableHexFile {
    
    static var defaultProgram: DefaultProgram = DefaultProgram()
    
    let loadableProgramName = "Start Program"
    let loadableProgramURL = UserDefaults.standard.string(forKey: SettingsKey.defaultHexFileURL.rawValue)!
    
    lazy var downloadedHexFile: HexFile? = storedHexFileInitializer()
    
    private init() {}
}
