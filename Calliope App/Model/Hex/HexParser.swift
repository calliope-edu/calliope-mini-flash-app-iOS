import Foundation

struct HexParser {
    
    // MARK: - Properties
    
    private var url: URL
    

    // MARK: - Initialization
    
    init(url: URL) {
        self.url = url
    }
    
    // MARK: - Hex Version Detection
    
    enum HexVersion: String, CaseIterable {
        case v3        = ":1000000000040020810A000015070000610A0000BA"
        case v2        = ":020000040000FA"
        case universal = ":0400000A9900C0DEBB"
        case arcade    = ":10000000000002202D5A0100555A0100575A0100E4"
        case invalid   = ""
    }


    /// Detects hex file version by examining the first two lines
    /// - Returns: Set of detected hex versions (v3, v2, universal, arcade, or invalid)
    func getHexVersion() -> Set<HexVersion> {
        let urlAccess = url.startAccessingSecurityScopedResource()
        guard let reader = StreamReader(path: url.path) else {
            return [.invalid]
        }
        
        defer {
            reader.close()
            if urlAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Read first two lines to determine version
        let firstLine = reader.nextLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let secondLine = reader.nextLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let relevantLines: Set<String> = [firstLine, secondLine]
        
        // Check which versions match
        var detectedVersions = Set<HexVersion>()
        for version in HexVersion.allCases {
            if relevantLines.contains(version.rawValue) {
                detectedVersions.insert(version)
            }
        }
        
        return detectedVersions.isEmpty ? [.invalid] : detectedVersions
    }
    
    // MARK: - Hex Parsing

    /// Parses hex file and calls handler for each data entry
    /// - Parameter handleDataEntry: Closure called for each data record with (address, data, dataType, isUniversal)
    func parse(handleDataEntry: (UInt32, Data, Int, Bool) -> ()) {
        let urlAccess = url.startAccessingSecurityScopedResource()
        guard let reader = StreamReader(path: url.path) else {
            return
        }

        defer {
            reader.close()
            if urlAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var isUniversal: Bool = false
        var addressHi: UInt32 = 0
        var beginIndex = 0
        var endIndex = 0
        // 0 = undefined, 1 = V1/2, 2 = V3
        var dataType = 0

        while let line = reader.nextLine() {

            // https://en.wikipedia.org/wiki/Intel_HEX
            // frame setup
            // idx      [0, 1-2,            3-6,        7-8,    9 - (end-2), (end-2) - end]
            // frame    [:, payload-length, address,    type,   payload,     checksum]
            // example  [:  10              b3f0        00      00208..,     E9]
            beginIndex = 0

            endIndex = beginIndex + 1 // begin 0 end 1
            guard line[beginIndex] == ":" else {
                return
            }
            beginIndex = endIndex

            endIndex = beginIndex + 2 // begin 1 end 3
            guard let length = UInt8(line[beginIndex..<endIndex], radix: 16) else {
                return
            }
            beginIndex = endIndex

            endIndex = beginIndex + 4 // begin 3 end 7
            guard let addressLo = UInt32(line[beginIndex..<endIndex], radix: 16) else {
                return
            }
            beginIndex = endIndex

            endIndex = beginIndex + 2 // begin 7 end 9
            guard let type = HexReader.type(of: line) else {
                return
            }
            beginIndex = endIndex

            endIndex = beginIndex + 2 * Int(length) // begin 9 end 9 + 2 * payload length
            let payload = line[beginIndex..<endIndex]
            beginIndex = endIndex

            switch (type) {
            case 0, 13: // Data
                let position = addressHi + addressLo
                guard let data = payload.toData(using: .hex) else {
                    return
                }
                guard data.count == Int(length) else {
                    return
                }
                handleDataEntry(position, data, dataType, isUniversal)
                break
            case 1: // EOF
                return
            case 2: // EXT SEGEMENT ADDRESS
                guard let segment = UInt32(payload, radix: 16) else {
                    return
                }
                addressHi = segment << 4
            case 3: // START SEGMENT ADDRESS
                break
            case 4: // EXT LINEAR ADDRESS
                guard let segment = UInt32(payload, radix: 16) else {
                    return
                }
                addressHi = segment << 16
            case 5: // START LINEAR ADDRESS
                break
            case 10: // Block Start Adress
                isUniversal = true
                let dataTypeField = line[9..<13]
                if dataTypeField == "9900" {
                    dataType = 1
                }
                if dataTypeField == "9903" {
                    dataType = 2
                }
                break
            case 12: // PADDED DATA
                break
            case 14: // CUSTOM DATA
                break
            default:
                break
            }
        }
    }

    /// Retrieves partial flashing information from hex file
    /// Delegates to PartialFlashManager for all partial flash functionality
    func retrievePartialFlashingInfo() -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
        return PartialFlashManager.retrievePartialFlashingInfo(from: url)
    }
}

struct HexReader {

    static let MAGIC_START_NUMBER = "708E3B92C615A841C49866C975EE5197"
    static let MAGIC_END_NUMBER = "41140E2FB82FA2B"
    static let EOF_NUMBER = "00000001FF"

    static func readSegmentAddress(_ record: String) -> UInt16? {
        if let length = length(of: record), length == 2,
           validate(record, length),
           let data = data(of: record, length) {
            return UInt16(bigEndianData: data)
        } else {
            return nil
        }
    }

    static func readData(_ record: String) -> (address: UInt16, data: Data)? {
        if let length = length(of: record),
           validate(record, length),
           let address = address(of: record),
           let data = data(of: record, length) {
            return (address, data)
        } else {
            return nil
        }
    }

    static func validate(_ record: String, _ length: Int) -> Bool {
        return record.trimmingCharacters(in: .whitespacesAndNewlines).count == 9 + 2 * length + 2
    }

    static func type(of record: String) -> Int? {
        guard record.count >= 9 else {
            return nil
        }
        return Int(record[7..<9], radix: 16)
    }

    static func length(of record: String) -> Int? {
        guard record.count >= 3 else {
            return nil
        }
        return Int(record[1..<3], radix: 16)
    }

    static func address(of record: String) -> UInt16? {
        guard record.count >= 7 else {
            return nil
        }
        return UInt16(record[3..<7], radix: 16)
    }

    static func data(of record: String, _ length: Int) -> Data? {
        return record[9..<(9 + 2 * length)].toData(using: .hex)
    }

    static func isMagicStart(_ record: String) -> Bool {
        record.count >= 41 && record[9..<41] == MAGIC_START_NUMBER
    }

    static func isEndOfFileOrMagicEnd(_ record: String) -> Bool {
        return record.count >= 24 && record[9..<24] == MAGIC_END_NUMBER || record.contains("00000001FF")
    }
}
