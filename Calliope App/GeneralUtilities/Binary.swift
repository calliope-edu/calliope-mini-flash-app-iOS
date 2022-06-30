import Foundation

final class Binary {

    enum Endianness {
        case little
        case big
    }

    public static func pack(format: String, values:[Any]) -> Data {
        let encoder = Encoder()
        var v = 0
	for f in format {
//                    case "x":       opStream.append(.SkipByte)
//                    case "c":       opStream.append(.PackChar)
//                    case "?":       opStream.append(.PackBool)
//                    case "f":       opStream.append(.PackFloat)
//                    case "d":       opStream.append(.PackDouble)
//                    case "s":       opStream.append(.PackCString)
//                    case "p":       opStream.append(.PackPString)
//                    case "P":       opStream.append(.PackPointer)
            switch f {
            case ">":
                encoder.endianness = .big
            case "<":
                encoder.endianness = .little

            case "b": // int8
                break
            case "B": // uint8
                if let raw = values[v] as? UInt8 {
                    encoder.append(raw)
                } else {
                    print(f,"invalid type")
                }
                v += 1

            case "h": // int16
                break
            case "H": // uint16
                if let raw = values[v] as? UInt16 {
                    encoder.append(raw)
                } else {
                    print(f,"invalid type")
                }
                v += 1

            case "i", "l": // int32
                break
            case "I", "L": // uint32
                if let raw = values[v] as? UInt32 {
                    encoder.append(raw)
                } else {
                    print(f,"invalid type")
                }
                v += 1

            case "q": // int64
                break
            case "Q": // uint64
                if let raw = values[v] as? UInt64 {
                    encoder.append(raw)
                } else {
                    print(f,"invalid type")
                }
                v += 1


            default:
                print(f,"invalid format char")
            }
        }
        return encoder.data
    }

    final class Encoder {

        public private(set) var data = Data()
        public var endianness = Endianness.big

        func append(_ i: UInt8) {
            data.append(contentsOf: [i])
        }

        func append(_ i: UInt16) {
            let n0 = UInt8(i & 0xFF)
            let n1 = UInt8((i >> 8) & 0xFF)
            switch endianness {
            case .little:
                data.append(contentsOf:[ n0, n1 ])
            case .big:
                data.append(contentsOf:[ n1, n0 ])
            }
        }

        func append(_ i: UInt32) {
            let n0 = UInt8(i & 0xFF)
            let n1 = UInt8((i >> 8) & 0xFF)
            let n2 = UInt8((i >> 16) & 0xFF)
            let n3 = UInt8((i >> 24) & 0xFF)
            switch endianness {
            case .little:
                data.append(contentsOf:[ n0, n1, n2, n3 ])
            case .big:
                data.append(contentsOf:[ n3, n2, n1, n0 ])
            }
        }

        func append(_ i: UInt64) {
            let n0 = UInt8(i & 0xFF)
            let n1 = UInt8((i >> 8) & 0xFF)
            let n2 = UInt8((i >> 16) & 0xFF)
            let n3 = UInt8((i >> 24) & 0xFF)
            let n4 = UInt8((i >> 32) & 0xFF)
            let n5 = UInt8((i >> 40) & 0xFF)
            let n6 = UInt8((i >> 48) & 0xFF)
            let n7 = UInt8((i >> 56) & 0xFF)

            switch endianness {
            case .little:
                data.append(contentsOf:[ n0, n1, n2, n3, n4, n5, n6, n7 ])
            case .big:
                data.append(contentsOf:[ n7, n6, n5, n4, n3, n2, n1, n0 ])
            }
        }

    }

}


