//
//  DownloadableHexFile.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.12.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

protocol DownloadableHexFile: Hex, AnyObject {
    var downloadedHexFile: HexFile? { get set }
    var loadableProgramName: String { get }
    var loadableProgramURL: String { get }
    var downloadFile: Bool { get set }
}

extension DownloadableHexFile {
    
    var date: Date {
        return downloadedHexFile?.date ?? Date()
    }
    var url: URL {
        downloadedHexFile?.url ?? (URL(string: loadableProgramURL) ?? URL(string: "/")!)
    }
    var name: String {
        return downloadedHexFile?.name ?? loadableProgramName
    }
    var calliopeV1andV2Bin: Data {
        return downloadedHexFile?.calliopeV1andV2Bin ?? loadExternalData()
    }
    var calliopeV3Bin: Data {
        return downloadedHexFile?.calliopeV3Bin ?? loadExternalData()
    }
    
    var calliopeUSBUrl: URL {
        return downloadedHexFile?.calliopeUSBUrl ?? URL(string: "/")!
    }
    
    var partialFlashingInfo: (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
        return downloadedHexFile?.partialFlashingInfo 
    }
    
    private func loadExternalData() -> Data {
        let url = URL(string: loadableProgramURL) ?? URL(string: "/")!
        let parser = HexParser(url:url)
        var bin = Data()
        parser.parse { (address, data, dataType, isUniversal) in
            if address >= 0x1C000 && address < 0x77000 {
                bin.append(data)
            }
        }
        return bin
    }
    
    public func load(completion: @escaping (Error?) -> ()) {
        let url = URL(string: loadableProgramURL)!
        let task = URLSession.shared.dataTask(with: url) {data, response, error in
            if (self.downloadFile) {
                guard error == nil, let data = data, data.count > 0, let hexFile = try? HexFileManager.store(name: self.loadableProgramName, data: data), hexFile.calliopeV1andV2Bin.count > 0 || hexFile.calliopeV3Bin.count > 0 else {
                    //file saving or parsing issue!
                    completion(error ?? NSLocalizedString("Could not save file or download is not a proper hex file", comment: ""))
                    return
                }
                //everything went smooth
                self.downloadedHexFile = hexFile
                completion(nil)
            } else {
                guard error == nil, let data = data, data.count > 0 else {
                    //file saving or parsing issue!
                    completion(error ?? NSLocalizedString("Could not save file or download is not a proper hex file", comment: ""))
                    return
                }
                let hexFile = HexFile(url: url, name: self.name, date: Date())
                //everything went smooth
                self.downloadedHexFile = hexFile
                completion(nil)
            }
        }
        task.resume()
    }
    
    /// use this initializer for downloadedHexFile to retrieve already-downloaded hex file
    public func storedHexFileInitializer() -> HexFile? {
        if let stored = (try? HexFileManager.stored())?.filter({ $0.name == loadableProgramName }),
            stored.count > 0 {
            return stored[0]
        } else {
            return nil
        }
    }
    
    func getHexTypes() -> Set<HexParser.HexVersion>{
        return HexParser(url: url).getHexVersion()
    }
}
