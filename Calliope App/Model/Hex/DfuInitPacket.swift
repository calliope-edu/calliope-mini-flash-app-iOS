import Foundation

import Foundation
import CryptoKit // For SHA-256 hashing if needed

struct DfuInitPacket {
    var firmwareVersion: Data = "microbit_app".data(using: .utf8)!
    var hardwareVersion: UInt32 = 1
    var softdeviceReq: [UInt32] = [0x0064]
    var appSize: UInt32
    var blSize: UInt32?
    var sdSize: UInt32?
    var hashType: UInt32 = 0
    var hash: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    var signature: Data?

    init(_ app: Data, _ bootloader: Data?, _ softdevice: Data?) {
        self.appSize = UInt32(app.count)

        if let bootloader {
            self.blSize = UInt32(bootloader.count)
        }

        if let softdevice {
            self.sdSize = UInt32(softdevice.count)
        }
    }

    func toData() -> Data {
        var data = Data()

        // Encode firmware version (4 bytes)
        data.append(contentsOf: firmwareVersion)

        // Encode hardware version (4 bytes)
        data.append(contentsOf: hardwareVersion.toBytes())

        // Encode SoftDevice requirement list length and values (4 bytes each)
//        data.append(contentsOf: UInt32(softdeviceReq.count).toBytes()) // Length of softdevice_req array
//        for sdVersion in softdeviceReq {
//            data.append(contentsOf: sdVersion.toBytes())
//        }

        // Encode application size (4 bytes)
        data.append(contentsOf: appSize.toBytes())
        // Encode bootloader size (4 bytes)
        if let blSize {
            data.append(contentsOf: blSize.toBytes())
        }
        // Encode sdSize size (4 bytes)
        if let sdSize {
            data.append(contentsOf: sdSize.toBytes())
        }

        // Encode hash type (4 bytes, e.g., 1 for SHA-256)
        data.append(contentsOf: hashType.toBytes())

        // Encode hash (32 bytes for SHA-256)
        data.append(contentsOf: hash)

        // Encode signature if available (optional, assuming length is known)
        if let signature = signature {
            data.append(signature)
        }

        return data
    }
}

// Helper extension to convert UInt32 to bytes
extension UInt32 {
    func toBytes() -> [UInt8] {
        let byteArray: [UInt8] = [
            UInt8(self & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 24) & 0xFF)
        ]
        return byteArray
    }
}


