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
    var calliopeArcadeBin: Data {
        return downloadedHexFile?.calliopeArcadeBin ?? loadArcadeData()
    }

    private func loadArcadeData() -> Data {
        guard let url = URL(string: loadableProgramURL) else { return Data() }
        do {
            return try Data(contentsOf: url)
        } catch {
            return Data()
        }
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
        print("🔽 DownloadableHexFile.load() starting for URL: \(url)")
        print("🔽 downloadFile flag: \(self.downloadFile)")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            print("🔽 Download completed, data size: \(data?.count ?? 0), error: \(String(describing: error))")
            
            if self.downloadFile {
                print("🔽 Taking downloadFile=true path")
                guard
                    error == nil,
                    let data = data,
                    data.count > 0,
                    let hexFile = try? HexFileManager.store(name: self.loadableProgramName, data: data)
                else {
                    completion(error ?? NSLocalizedString("Could not save file or download is not a proper hex file", comment: ""))
                    return
                }

                let types = hexFile.getHexTypes()
                let isValid =
                    types.contains(.v2) ||
                    types.contains(.v3) ||
                    types.contains(.v3Shield) ||
                    types.contains(.universal) ||
                    types.contains(.arcade)
                
                print("🔽 HexFile types: \(types), isValid: \(isValid)")

                guard isValid else {
                    completion(NSLocalizedString("Download is not a proper hex file", comment: ""))
                    return
                }

                self.downloadedHexFile = hexFile
                print("🔽 downloadedHexFile set, checking bin sizes:")
                print("🔽 calliopeV1andV2Bin.count: \(self.calliopeV1andV2Bin.count)")
                print("🔽 calliopeV3Bin.count: \(self.calliopeV3Bin.count)")
                print("🔽 downloadedHexFile?.calliopeV1andV2Bin.count: \(self.downloadedHexFile?.calliopeV1andV2Bin.count ?? -1)")
                
                completion(nil)
            } else {
                guard error == nil, let data = data, data.count > 0 else {
                    completion(error ?? NSLocalizedString("Could not save file or download is not a proper hex file", comment: ""))
                    return
                }
                let hexFile = HexFile(url: url, name: self.name, date: Date())
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
