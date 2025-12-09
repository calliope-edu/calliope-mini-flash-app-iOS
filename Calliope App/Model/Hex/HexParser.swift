import Foundation

struct HexParser {

    private var url: URL

    init(url: URL) {
        self.url = url
    }

    private func calcChecksum(_ address: UInt16, _ type: UInt8, _ data: Data) -> UInt8 {
        var crc: UInt8 = UInt8(data.count)
            + UInt8(address >> 8)
            + UInt8(address + UInt16(type))
        for b in data {
            crc = crc + b
        }
        return UInt8((0x100 - UInt16(crc)))
    }

    enum HexVersion: String, CaseIterable {

        case v3 = ":1000000000040020810A000015070000610A0000BA"
        case v2 = ":020000040000FA"
        case universal = ":0400000A9900C0DEBB"
        case invalid = ""
    }

    func getHexVersion() -> Set<HexVersion> {
        let urlAccess = url.startAccessingSecurityScopedResource()
        guard let reader = StreamReader(path: url.path) else {
            var enumSet: Set<HexVersion> = Set.init()
            enumSet.insert(.invalid)
            return enumSet
        }

        defer {
            reader.close()
            if urlAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var relevantLines: Set<String> = Set.init()
        relevantLines.insert(reader.nextLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        relevantLines.insert(reader.nextLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")

        var enumSet: Set<HexVersion> = Set.init()
        for version in HexVersion.allCases {
            if relevantLines.contains(version.rawValue) {
                enumSet.insert(version)
            }
        }
        if enumSet.isEmpty {
            enumSet.insert(.invalid)
        }
        return enumSet
    }

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

    func retrievePartialFlashingInfo() -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
        guard let reader = StreamReader(path: url.path) else {
            return nil
        }

        _ = forwardToMagicNumber(reader)
        var numLinesToFlash = 0
        while let line = reader.nextLine(), !HexReader.isEndOfFileOrMagicEnd(line) {
            if line.starts(with: ":") && HexReader.type(of: line) == 0 {
                numLinesToFlash += 1
            }
        }
        reader.rewind()

        let (magicLine, currentSegmentAddress) = forwardToMagicNumber(reader)
        guard let magicLineUnwrapped = magicLine else {
            return nil
        }

        // Determine endMarkerAddress from the checksum block (the line before magicLine)
        // The checksum block is assumed to be the line before magicLine in stream order,
        // so rewind to start and find the checksum block line by iterating until magicLine.
        var endMarkerAddressValue: UInt16? = nil

        reader.rewind()
        var prevLine: String? = nil
        while let line = reader.nextLine() {
            if line == magicLineUnwrapped {
                break
            }
            prevLine = line
        }
        if let checksumBlockLine = prevLine {
            // Parse the checksum block line:
            // It should be a record of type 0, with data length >= 8 bytes (to read offset 4..7)
            if HexReader.type(of: checksumBlockLine) == 0,
               let length = HexReader.length(of: checksumBlockLine),
               length >= 8,
               let data = HexReader.data(of: checksumBlockLine, length) {
                // The offset 4 (zero-based) means bytes 4..7 (4 bytes, little-endian)
                if data.count >= 8 {
                    let endMarkerData = data.subdata(in: 4..<8)
                    // convert 4-byte little endian data to UInt32, then downcast to UInt16 (low 16 bits)
                    let endMarkerUInt32 = endMarkerData.withUnsafeBytes { ptr -> UInt32 in
                        ptr.load(as: UInt32.self)
                    }
                    endMarkerAddressValue = UInt16(truncatingIfNeeded: endMarkerUInt32)
                }
            }
        }

        if let hashesLine = reader.nextLine(),
           hashesLine.count >= 41,
           let templateHash = hashesLine[9..<25].toData(using: .hex),
           let programHash = (hashesLine[25..<41]).toData(using: .hex) {
            return (templateHash,
                programHash,
                PartialFlashData(
                    nextLines: [hashesLine, magicLineUnwrapped],
                    currentSegmentAddress: currentSegmentAddress,
                    reader: reader,
                    lineCount: numLinesToFlash,
                    endMarkerAddress: endMarkerAddressValue))
        }
        return nil
    }

    private func forwardToMagicNumber(_ reader: StreamReader) -> (String?, UInt16) {
        var magicLine: String?

        var currentSegmentAddress: UInt16 = 0
        while let record = reader.nextLine() {
            if HexReader.isMagicStart(record) {
                magicLine = record
                break
            } else if HexReader.type(of: record) == 4,
                      let segmentAddress = HexReader.readSegmentAddress(record) {
                currentSegmentAddress = segmentAddress
            }
        }
        return (magicLine, currentSegmentAddress)
    }
}

struct PartialFlashData: Sequence, IteratorProtocol {
    typealias Element = (address: UInt16, data: Data)

    public let lineCount: Int
    public private(set) var currentSegmentAddress: UInt16
    private var nextData: [(address: UInt16, data: Data)] = []
    private var reader: StreamReader?

    private var endMarkerChunk: (address: UInt16, data: Data)?
    private let endMarkerAddress: UInt16?

    init(nextLines: [String], currentSegmentAddress: UInt16, reader: StreamReader, lineCount: Int, endMarkerAddress: UInt16? = nil) {
        self.reader = reader
        self.nextData = []
        self.currentSegmentAddress = currentSegmentAddress
        self.lineCount = lineCount
        self.endMarkerAddress = endMarkerAddress
        //extract data from nextLines
        nextLines.forEach {
            read($0)
        }
    }

    mutating func next() -> (address: UInt16, data: Data)? {
        // First try to return from nextData
        let line = nextData.popLast()
        // If none and still have reader, read more lines
        while let reader = reader, nextData.count == 0 {
            guard let record = reader.nextLine() else {
                break
            }
            read(record)
        }
        // If line is nil and endMarkerChunk exists, return it now
        if line == nil, let endChunk = endMarkerChunk {
            endMarkerChunk = nil
            return endChunk
        }
        return line
    }

    mutating private func read(_ record: String) {
        if HexReader.isEndOfFileOrMagicEnd(record) {
            reader?.close()
            reader = nil
            return
        }
        switch HexReader.type(of: record) {
        case 0: //record type 0 means data for program
            if record.contains("00000001FF") {
                break
            } else if let data = HexReader.readData(record) {
                if let endAddr = endMarkerAddress, data.address == endAddr {
                    // Store end marker chunk separately
                    endMarkerChunk = data
                } else {
                    nextData.append(data)
                }
            }
        case 2: // extended segment adress
            if let segmentAddress = HexReader.readSegmentAddress(record) {
                currentSegmentAddress = segmentAddress
            }
        case 4: //segment address type
            if let segmentAddress = HexReader.readSegmentAddress(record) {
                currentSegmentAddress = segmentAddress
            }
        default:
            break
        }
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
        //string starting at 10th character must be 2*length characters long plus two characters for the checksum
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
        //address in the program is encoded with two bytes
        guard record.count >= 7 else {
            return nil
        }
        return UInt16(record[3..<7], radix: 16)
    }

    static func data(of record: String, _ length: Int) -> Data? {
        //data area with given byte length
        return record[9..<(9 + 2 * length)].toData(using: .hex)
    }

    static func isMagicStart(_ record: String) -> Bool {
        record.count >= 41 && record[9..<41] == MAGIC_START_NUMBER
    }

    static func isEndOfFileOrMagicEnd(_ record: String) -> Bool {
        //magic end of program data (start of embedded source)
        return record.count >= 24 && record[9..<24] == MAGIC_END_NUMBER || record.contains("00000001FF")
    }
}
