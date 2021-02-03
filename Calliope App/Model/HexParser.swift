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

        if let reader = StreamReader(path: url.path) {

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
        } else {
            print("no path")
        }
    }

    func findDalHash() -> Data? {
        guard let data = try? Data(contentsOf: url),
              let magicConstant = "708E3B92C615A841C49866C975EE5197".toData(using: .hex) else {
            return nil
        }
        let hashLength = 16
        for i in 0..<(data.count-magicConstant.count-hashLength) {
            let constantEnd = i+magicConstant.count
            if data.subdata(in: i..<constantEnd) == magicConstant {
                return data.subdata(in: constantEnd..<constantEnd+hashLength)
            }
        }
        return nil
    }
}
