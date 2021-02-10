import Foundation

final class HexParser {

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

    func parse(f: (UInt32,Data) -> ()) {

        guard let reader = StreamReader(path: url.path) else {
            return
        }

        defer {
            reader.close()
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
            guard let type = UInt8(line[b..<e], radix: 16) else { return }
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

        guard let magicLine = forwardToMagicNumber(reader) else {
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
                        reader: reader))
        }
        return nil
    }

    private func forwardToMagicNumber(_ reader: StreamReader) -> String? {
        var magicLine: String?

        let magicNumber =  "708E3B92C615A841C49866C975EE5197"
        while let line = reader.nextLine() {
            if line.count >= 41 && line[9..<41] == magicNumber {
                magicLine = line
                break
            }
        }
        return magicLine
    }
}

struct PartialFlashData: Sequence, IteratorProtocol {
    typealias Element = (address: Int, data: Data)

    private var nextData: [(address: Int, data: Data)] = []
    private var reader: StreamReader

    init(nextLines: [String], reader: StreamReader) {
        self.reader = reader
        self.nextData = []
        self.nextData.append(contentsOf: nextLines.compactMap { line in readData(line) }) //data from nextLines
    }

    mutating func next() -> (address: Int, data: Data)? {
        let line = nextData.popLast()
        if nextData.count == 0 {
            if let nextReaderLine = reader.nextLine(), let nextLine = readData(nextReaderLine) {
                nextData.append(nextLine)
            } else {
                reader.close()
            }
        }
        return line
    }

    private func readData(_ record: String) -> (address: Int, data: Data)? {
        guard record.count >= 9, record[7..<9] == "00", //record type 00 means data for program
              let address = Int(record[3..<7], radix: 16), //address in the program is encoded with four bytes
              let length = Int(record[1..<3], radix: 16), //record length
              record.count >= 9+2*length,
              let data = record[9..<(9+2*length)].toData(using: .hex) //data area with given byte length (2 letters per byte)
        else {
            return nil
        }
        return (address, data)
    }
}
