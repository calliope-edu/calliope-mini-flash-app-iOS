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
    
    let loadableProgramName = NSLocalizedString("Start Program", comment:"")
    let loadableProgramURL = UserDefaults.standard.string(forKey: SettingsKey.defaultHexFileURL.rawValue)!
    
    lazy var downloadedHexFile: HexFile? = storedHexFileInitializer()
    
    private init() {}
}


class QRCodeHexFile: DownloadableHexFile {
    var downloadedHexFile: HexFile?
    
    var loadableProgramName: String
    
    var loadableProgramURL: String
    
    init (url: String) {
        loadableProgramName = "Test_File"
        loadableProgramURL = url
    }
}
