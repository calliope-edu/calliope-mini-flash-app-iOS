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
}

extension DownloadableHexFile {
    
    var date: Date {
        return downloadedHexFile?.date ?? Date()
    }
    var url: URL {
        downloadedHexFile?.url ?? URL(string: "/")!
    }
    var name: String {
        return downloadedHexFile?.name ?? loadableProgramName
    }
    var bin: Data {
        return downloadedHexFile?.bin ?? Data()
    }
    
    public func load(completion: @escaping (Error?) -> ()) {
        let url = URL(string: loadableProgramURL)!
        let task = URLSession.shared.dataTask(with: url) {data, response, error in
            guard error == nil, let data = data, let hexFile = try? HexFileManager.store(name: self.loadableProgramName, data: data) else {
                //no download error -> file save error!
                completion(error ?? "Could not save file")
                return
            }
            //everything went smooth
            self.downloadedHexFile = hexFile
            completion(nil)
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
}
