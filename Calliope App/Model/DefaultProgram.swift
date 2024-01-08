//
//  DefaultProgram.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.11.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

class DefaultProgram: DownloadableHexFile {

    var loadableProgramName = NSLocalizedString("Calliope mini 3", comment:"")
    var loadableProgramURL = UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV3Url.rawValue)!
    var downloadFile: Bool = true
    
    lazy var downloadedHexFile: HexFile? = storedHexFileInitializer()
    
    init(programName: String, url: String) {
        loadableProgramName = programName
        loadableProgramURL = url
    }
}


class QRCodeHexFile: DownloadableHexFile {
    var downloadFile: Bool
    
    var downloadedHexFile: HexFile?
    
    var loadableProgramName: String
    
    var loadableProgramURL: String
    
    init (url: String) {
        loadableProgramName = "Test_File"
        loadableProgramURL = url
        downloadFile = true
    }
}
