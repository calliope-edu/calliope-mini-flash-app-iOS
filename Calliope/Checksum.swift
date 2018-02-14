final class Checksum {

    public static func crc16(_ data: [UInt8]) -> UInt16 {

        var crc = UInt16(0xffff)

        for b in data {
            crc = (crc >> 8 & 0x00FF) | (crc << 8 & 0xFF00)
            crc ^= (UInt16(b) & 0x00FF)
            crc ^= (crc & 0x00FF) >> 4
            crc ^= (crc << 8) << 4
            crc ^= ((crc & 0x00FF) << 4) << 1
        }

        return crc
    }
}
