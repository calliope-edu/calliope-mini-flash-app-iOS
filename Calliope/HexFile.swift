import UIKit
import iOSDFULibrary

struct HexFile {

    let url: URL
	var name: String {
		didSet {
			let lastURLPart = url.lastPathComponent.dropLast(4)
			if lastURLPart != name {
				do {
					try HexFileManager.rename(file: self)
				} catch {
					//reset name
					name = String(lastURLPart)
					//FIXME: display to user
				}
			}
		}
	}
    let date: Date

    func bin() -> Data {

        let parser = HexParser(url:url)
        var bin = Data()
        parser.parse { (address, data) in
            if address >= 0x18000 && address < 0x40000 {
                bin.append(data)
            }
        }

        return bin
    }

    static func dat(_ data: Data) -> Data {

        let deviceType: UInt16 = 0xffff
        let deviceRevision: UInt16 = 0xffff
        let applicationVersion: UInt32 = 0xffffffff
        let softdevicesCount: UInt16 = 0x0001
        let softdevice: UInt16 = 0x0064
        let checksum = Checksum.crc16([UInt8](data))

        let d = Binary.pack(format:"<HHLHHH", values:[
            deviceType,
            deviceRevision,
            applicationVersion,
            softdevicesCount,
            softdevice,
            checksum
        ])

        return d
    }
}

final class HexFileManager {

    private static let keep = 5

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

    public static func store(name: String, data: Data) throws -> HexFile {
        let dir = try self.dir()
        let file = dir.appendingPathComponent(name + ".hex")
        LOG("writing file \(file)")
        try data.write(to: file)

        let files = try stored()
        let filesKeep = files.prefix(keep)
        let filesRemove = files.suffix(files.count - filesKeep.count)

        for file in filesRemove {
            try delete(file: file)
        }

        return HexFile(url: file, name: name, date:Date())
    }

    public static func delete(file: HexFile) throws {
        LOG("deleting file \(file)")
        try FileManager.default.removeItem(at: file.url)
    }

	public static func rename(file: HexFile) throws {
		LOG("renaming file \(file)")
		try FileManager.default.moveItem(at: file.url, to: file.url.deletingLastPathComponent().appendingPathComponent(file.name + ".hex"))
	}

}
