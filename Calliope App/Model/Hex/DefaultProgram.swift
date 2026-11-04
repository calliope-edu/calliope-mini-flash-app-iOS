//
//  DefaultProgram.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.11.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

class DefaultProgram: DownloadableHexFile {

    var loadableProgramName: String
    var loadableProgramURL: String
    var downloadFile: Bool = true
    
    lazy var downloadedHexFile: HexFile? = storedHexFileInitializer()
    
    init(programName: String, url: String) {
        loadableProgramName = programName
        loadableProgramURL = url
    }
}
