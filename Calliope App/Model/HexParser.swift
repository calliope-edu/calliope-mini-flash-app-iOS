import Foundation

struct HexParser {

    private let url: URL
    private var address: UInt32 = 0

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
        _ = url.startAccessingSecurityScopedResource()
        guard let reader = StreamReader(path: url.path) else {
            var enumSet: Set<HexVersion> = Set.init()
            enumSet.insert(.invalid)
            return enumSet
        }

        defer {
            reader.close()
            url.stopAccessingSecurityScopedResource()
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

    func parse(f: (UInt32,Data) -> ()) {

        _ = url.startAccessingSecurityScopedResource()
        guard let reader = StreamReader(path: url.path) else {
            return
        }

        defer {
            reader.close()
            url.stopAccessingSecurityScopedResource()
        }

        var addressHi: UInt32 = 0
        var n = 0
        var b = 0
        var e = 0
        while let line = reader.nextLine() {

            b = 0

            e = b + 1
            guard line[b] == ":" else { return }
            b = e

            e = b + 2
            guard let length = UInt8(line[b..<e], radix: 16) else { return }
            b = e

            e = b + 4
            guard let addressLo = UInt32(line[b..<e], radix: 16) else { return }
            b = e

            e = b + 2
            guard let type = HexReader.type(of: line) else { return }
            b = e

            e = b + 2 * Int(length)
            let payload = line[b..<e]
            b = e

            // FIXME
            //                e = b + 2
            //                guard let checksum = UInt8(line[b..<e], radix: 16) else { return }
            //                b = e
            //
            //                guard checksum == calcChecksum(addressLo, type, data) else {
            //                    print("checksum", checksum, calcChecksum(addressLo, type, data))
            //                return }

            switch(type) {
            case 0: // DATA
                let position = addressHi + addressLo
                guard let data = payload.toData(using: .hex) else { return }
                guard data.count == Int(length) else { return }
                f(position, data)
            case 1: // EOF
                return
            case 2: // EXT SEGEMENT ADDRESS
                guard let segment = UInt32(payload, radix:16) else { return }
                addressHi = segment << 4
            // print(String(format:"EXT SEGEMENT ADDRESS 0x%x", addressHi + addressLo))
            case 3: // START SEGMENT ADDRESS
                // print("START SEGMENT ADDRESS")
                break
            case 4: // EXT LINEAR ADDRESS
                guard let segment = UInt32(payload, radix:16) else { return }
                addressHi = segment << 16
            // print(String(format:"EXT LINEAR ADDRESS 0x%x", addressHi + addressLo))
            case 5: // START LINEAR ADDRESS
                // print("START LINEAR ADDRESS")
                break
            default:
                return
            }

            n += 1
        }
    }

    func retrievePartialFlashingInfo() -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
        guard let reader = StreamReader(path: url.path) else {
            return nil
        }

        _ = forwardToMagicNumber(reader)
        var numLinesToFlash = 0
        while let line = reader.nextLine(), !HexReader.isMagicEnd(line) {
            numLinesToFlash += 1
        }
        reader.rewind()

        let (line, currentSegmentAddress) = forwardToMagicNumber(reader)
        guard let magicLine = line else {
            return nil
        }

        if let hashesLine = reader.nextLine(),
           hashesLine.count >= 41,
           let templateHash = hashesLine[9..<25].toData(using: .hex),
           let programHash = (hashesLine[25..<41]).toData(using: .hex) {
            return (templateHash,
                    programHash,
                    PartialFlashData(
                        nextLines: [hashesLine, magicLine],
                        currentSegmentAddress: currentSegmentAddress,
                        reader: reader,
                        lineCount: numLinesToFlash))
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

    init(nextLines: [String], currentSegmentAddress: UInt16, reader: StreamReader, lineCount: Int) {
        self.reader = reader
        self.nextData = []
        self.currentSegmentAddress = currentSegmentAddress
        self.lineCount = lineCount
        //extract data from nextLines
        nextLines.forEach { read($0) }
    }

    mutating func next() -> (address: UInt16, data: Data)? {
        let line = nextData.popLast()
        while let reader = reader, nextData.count == 0 {
            guard let record = reader.nextLine() else { break }
            read(record)
        }
        return line
    }

    mutating private func read(_ record: String) {
        if HexReader.isMagicEnd(record) {
            reader?.close()
            reader = nil
            return
        }
        switch HexReader.type(of: record) {
            case 0: //record type 0 means data for program
                if let data = HexReader.readData(record) {
                    nextData.append(data)
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
        return record.trimmingCharacters(in: .whitespacesAndNewlines).count == 9 + 2*length + 2
    }

    static func type(of record: String) -> Int? {
        return Int(record[7..<9], radix: 16)
    }

    static func length(of record: String) -> Int? {
        return Int(record[1..<3], radix: 16)
    }

    static func address(of record: String) -> UInt16? {
        //address in the program is encoded with two bytes
        return UInt16(record[3..<7], radix: 16)
    }

    static func data(of record: String, _ length: Int) -> Data? {
        //data area with given byte length
        return record[9..<(9+2*length)].toData(using: .hex)
    }

    static func isMagicStart(_ record: String) -> Bool {
        record.count >= 41 && record[9..<41] == "708E3B92C615A841C49866C975EE5197"
    }

    static func isMagicEnd(_ record: String) -> Bool {
        //magic end of program data (start of embedded source)
        return record.count >= 24 && record[9..<24] == "41140E2FB82FA2B"
    }
}
