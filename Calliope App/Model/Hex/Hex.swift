import UIKit
import NordicDFU
import DeepDiff

protocol Hex {
    var name: String { get }
    var date: Date { get }
    var dateString: String { get }
    var calliopeV1andV2Bin: Data { get }
    var calliopeV3Bin: Data { get }
    var calliopeUSBUrl: URL { get }
    var partialFlashingInfo: (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? { get }

    func getHexTypes() -> Set<HexParser.HexVersion>
}

struct InitPacket {
    let appName = "microbit_app".data(using: .utf8) ?? Data()   // identify this struct "microbit_app"
    let initPacketVersion: UInt32 = 1   // version of this struct == 1
    let appSize: UInt32 // only used for DFU_FW_TYPE_APPLICATION, DFU_FW_TYPE_EXTERNAL_APPLICATION
    let hashSize: UInt32 = 0    // 32 => DFU_HASH_TYPE_SHA256 or zero to bypass hash check
    let hashBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]    // hash of whole DFU download

    func encode() -> Data {
        var initPacket = Data()
        initPacket.append(appName)
        initPacket.append(initPacketVersion.littleEndianData)
        initPacket.append(appSize.littleEndianData)
        initPacket.append(hashSize.bigEndianData)
        initPacket.append(contentsOf: hashBytes)
        return initPacket
    }
}

extension Hex {

    var dateString: String {
        get {
            return HexFileManager.dateFormatter.string(from: date)
        }
    }

    static func calliopeV3InitPacket(_ data: Data) throws -> Data {
        let initPacket = InitPacket(appSize: UInt32(data.count))

        return initPacket.encode()
    }

    static func calliopeV1AndV2InitPacket(_ data: Data) -> Data {

        let deviceType: UInt16 = 0xffff
        let deviceRevision: UInt16 = 0xffff
        let applicationVersion: UInt32 = 0xffffffff
        let softdevicesCount: UInt16 = 0x0001
        let softdevice: UInt16 = 0x0064
        let checksum = Checksum.crc16([UInt8](data))

        let d = Binary.pack(format: "<HHLHHH", values: [
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

    var calliopeV1andV2Bin: Data {
        get {
            let parser = HexParser(url: url)
            var bin = Data()
            parser.parse { (address, data, dataType, isUniversal) in
                if address >= 0x18000 && address < 0x3C000 && (dataType == 1 || !isUniversal) {
                    bin.append(data)
                }
            }

            return bin
        }
    }

    var calliopeV3Bin: Data {
        get {
            let parser = HexParser(url: url)
            var partitiones: [(UInt32, Data)] = [] // (Start, Data)
            var lastAddress: UInt32 = 0

            parser.parse { address, data, dataType, isUniversal in

                if address >= 0x1c000 && address < 0x73000 {

                    if lastAddress > address || lastAddress + 16 < address { // JUMP
                        partitiones.append((address, Data()))
                    }

                    if let lastElementIndex = partitiones.indices.last {
                        partitiones[lastElementIndex].1.append(data)
                        lastAddress = address
                    }

                }
            }

            partitiones.sort { p1, p2 in
                p1.0 < p2.0
            }

            for (address, data) in partitiones {
                print("Partition Address at \(String(format: "%02X", address)) with size \(data.count) ends at \(String(format: "%02X", (address + (UInt32(data.count)))))")
            }


            var paddedApplication = Data()
            for idx in 0..<(partitiones.count - 1) {
                let current = partitiones[idx]
                let next = partitiones[idx + 1]

                // Append current Data
                paddedApplication.append(current.1)

                // Calculate number of padding
                let paddingSize = (Int(next.0 - (current.0 + (UInt32(current.1.count)))))
                let pad = Data([UInt8](repeating: 0xFF, count: paddingSize))
                paddedApplication.append(pad)
            }
            paddedApplication.append(partitiones.last!.1)

            print("Partitions")

            return paddedApplication
        }
    }
    var calliopeUSBUrl: URL {
        get {
            return url
        }
    }

    var partialFlashingInfo: (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
        get {
            let parser = HexParser(url: url)
            return parser.retrievePartialFlashingInfo()
        }
    }

    var downloadFile: Bool = true

    static func ==(lhs: HexFile, rhs: HexFile) -> Bool {
        return lhs.url == rhs.url && lhs.name == rhs.name
    }

    func getHexTypes() -> Set<HexParser.HexVersion> {
        return HexParser(url: url).getHexVersion()
    }
}

extension HexFile: DiffAware {
    typealias DiffId = URL
    var diffId: DiffId {
        return url
    }

    static func compareContent(_ a: HexFile, _ b: HexFile) -> Bool {
        return a == b
    }
}
