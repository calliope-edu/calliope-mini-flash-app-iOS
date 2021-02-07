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

        while let line = reader.nextLine() {
            if line.count < 41 || line[9..<41] != "708E3B92C615A841C49866C975EE5197" {
                continue
            }
            magicLine = line
        }
        return magicLine
    }
}

struct PartialFlashData: Sequence, IteratorProtocol {
    typealias Element = Data

    private var nextLines: [Data]
    private var reader: StreamReader

    init(nextLines: [String], reader: StreamReader) {
        self.nextLines = [] //data from nextLines
        self.reader = reader
    }

    mutating func next() -> Data? {
        let line = nextLines.popLast()
        if nextLines.count == 0 {
            nextLines.append(Data()) //TODO: read data from the next couple of lines from stream reader
        }
        return line
    }
}
