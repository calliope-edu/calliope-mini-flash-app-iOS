//
//  DefaultProgram.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.11.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

class DefaultProgram: Hex {
    
    static var defaultProgram: DefaultProgram = DefaultProgram()
    
    private init() {
        if let stored = (try? HexFileManager.stored())?.filter({ $0.name == "Demo Program" }),
            stored.count > 0 {
            defaultHexFile = stored[0]
        }
    }
    
    var date: Date {
        return defaultHexFile?.date ?? Date()
    }
    var url: URL {
        defaultHexFile?.url ?? URL(string: "/")!
    }
    var name: String {
        return defaultHexFile?.name ?? "Demo Program"
    }
    var bin: Data {
        return defaultHexFile?.bin ?? Data()
    }
    
    public func load(completion: @escaping (Error?) -> ()) {
        let url = URL(string: UserDefaults.standard.string(forKey: SettingsKey.defaultHexFileURL.rawValue)!)!
        let task = URLSession.shared.dataTask(with: url) {data, response, error in
            guard error == nil, let data = data, let hexFile = try? HexFileManager.store(name: "Demo Program", data: data) else {
                //no download error -> file save error!
                completion(error ?? "Could not save file")
                return
            }
            //everything went smooth
            self.defaultHexFile = hexFile
            completion(nil)
        }
        task.resume()
    }
    
    var defaultHexFile: HexFile?
}
