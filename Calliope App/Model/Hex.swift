import UIKit
import iOSDFULibrary
import DeepDiff

protocol Hex {
    var name: String { get }
    var date: Date { get }
    var dateString: String { get }
    var bin: Data { get }
    var partialFlashingInfo: (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? { get }
}

extension Hex {
    
    var dateString: String {
        get { return HexFileManager.dateFormatter.string(from: date) }
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

struct HexFile: Hex, Equatable {
    
    private(set) var url: URL
	
    var name: String {
		didSet {
			let lastURLPart = String(url.lastPathComponent.dropLast(4))
			if lastURLPart != name {
				if name == "" {
					name = lastURLPart
					return
				}
				do {
					try url = HexFileManager.rename(file: self)
				} catch {
					//reset name
					name = lastURLPart
				}
			}
		}
	}
    
    let date: Date

    var bin: Data {
        get {
            let parser = HexParser(url:url)
            var bin = Data()
            parser.parse { (address, data) in
                if address >= 0x18000 && address < 0x3C000 {
                    bin.append(data)
                }
            }
            
            return bin
        }
    }

    var partialFlashingInfo: (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
        get {
            let parser = HexParser(url: url)
            return parser.retrievePartialFlashingInfo()
        }
    }

	static func == (lhs: HexFile, rhs: HexFile) -> Bool {
		return lhs.url == rhs.url && lhs.name == rhs.name
	}
}

extension HexFile: DiffAware {
	typealias DiffId = URL
	var diffId: DiffId { return url }
	static func compareContent(_ a: HexFile, _ b: HexFile) -> Bool {
		return a == b
	}
}

final class HexFileManager {

	fileprivate static let dateFormatter: DateFormatter = {
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
			//TODO: load description from file somehow
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
			//TODO: load description from file somehow
			return HexFile(url: url, name: name, date: date)
        }.sorted(by: { (a,b) -> Bool in
            return a.date > b.date
        })
    }

    public static func store(name: String, data: Data, overrideDuplicate: Bool = true) throws -> HexFile {
        let dir = try self.dir()
        let file = dir.appendingPathComponent(name + ".hex")
        LogNotify.log("writing file \(file)")
        if !overrideDuplicate && FileManager.default.fileExists(atPath: file.path) {
            throw NSLocalizedString("File already exists", comment: "")
        }
        try data.write(to: file)
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
