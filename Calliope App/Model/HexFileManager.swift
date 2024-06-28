//
//  HexFileManager.swift
//  Calliope App
//
//  Created by itestra on 18.01.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

final class HexFileManager {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private static func dir() throws -> URL {
        return try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor:nil,
            create:false
        )
    }
    
    private static func dateFor(url:URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let date = attributes[.creationDate] as? Date else { throw "invalid date" }
        return date
    }
    
    public static func builtins() throws -> [HexFile] {
        let names = [
            "Calliope-mini-Start",
        ]
        return try names.map({ name -> HexFile in
            guard let url = Bundle.main.url(forResource: name, withExtension: "hex") else {
                throw "invalid url"
            }
            let date = try dateFor(url:url)
            return HexFile(url: url, name: name, date: date)
        })
    }
    
    public static func stored() throws -> [HexFile] {
        let dir = try self.dir()
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: .skipsSubdirectoryDescendants)
        return try urls.filter({ url -> Bool in
            return url.absoluteString.hasSuffix(".hex")
        })
        .map { url -> HexFile in
            let name = String(url.lastPathComponent.dropLast(4))
            let date = try dateFor(url:url)
            return HexFile(url: url, name: name, date: date)
        }.sorted(by: { (a,b) -> Bool in
            return a.date > b.date
        })
    }
    
    public static func store(name: String, data: Data, overrideDuplicate: Bool = true, isHexFile: Bool = true) throws -> HexFile? {
        let dir = try self.dir()
        let fileSuffix = isHexFile ? ".hex" : ".png"
        let file = dir.appendingPathComponent(name + fileSuffix)
        LogNotify.log("writing file \(file)")
        if !overrideDuplicate && FileManager.default.fileExists(atPath: file.path) {
            throw NSLocalizedString("File already exists", comment: "")
        }
        do {
            try data.write(to: file)
        } catch {
            print(error)
        }
        if !isHexFile {
            return nil
        }
        let date = Date()
        let hexFile = HexFile(url: file, name: name, date: date)
        notifyChange()
        return hexFile
    }
    
    public static func delete(file: HexFile) throws {
        LogNotify.log("deleting file \(file)")
        try FileManager.default.removeItem(at: file.url)
        notifyChange()
    }
    
    public static func rename(file: HexFile) throws -> URL {
        LogNotify.log("renaming file \(file)")
        let newURL = file.url.deletingLastPathComponent().appendingPathComponent(file.name + ".hex")
        try FileManager.default.moveItem(at: file.url, to: newURL)
        notifyChange()
        return newURL
    }
    
    public static var bulkChange = false {
        didSet {
            if oldValue == true && bulkChange == false {
                notifyChange()
            }
        }
    }
    
    private static func notifyChange() {
        if !bulkChange {
            NotificationCenter.default.post(name: NotificationConstants.hexFileChanged, object: self)
        }
    }
}
