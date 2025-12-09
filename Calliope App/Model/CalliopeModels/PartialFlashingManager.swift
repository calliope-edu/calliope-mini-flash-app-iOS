import Foundation
import CoreBluetooth

final class PartialFlashingManager: NSObject, CBPeripheralDelegate {

    // UUIDs for Partial Flashing (micro:bit v2 / Calliope mini v3)
    static let partialFlashingServiceUUID = CBUUID(string: "e97dd91d-251d-470a-a062-fa1922dfa9a8")
    static let partialFlashingCharacteristicUUID = CBUUID(string: "e97d3b10-251d-470a-a062-fa1922dfa9a8")
    static let secureDFUServiceUUID = CBUUID(string: "0000fe59-0000-1000-8000-00805f9b34fb")

    // MakeCode / MicroPython identification
    private static let PXT_MAGIC = "708E3B92C615A841C49866C975EE5197"
    private static let UPY_MAGIC_REGEX = ".*FE307F59.{16}9DD7B1C1.*"
    private static let UPY_MAGIC1 = "FE307F59"
    private static let UPY_MAGIC2 = "9DD7B1C1"

    // Commands
    private enum Command: UInt8 { case regionInfo = 0x00; case flash = 0x01 }

    // Public callbacks
    var onReadyForPartialFlash: (() -> Void)?
    var onProgress: ((Int) -> Void)?
    var onCompleted: (() -> Void)?
    var onError: ((Error) -> Void)?

    // State
    private weak var peripheral: CBPeripheral?
    private var pfCharacteristic: CBCharacteristic?

    // Memory map collected from notifications
    private struct RegionInfo { var id: UInt8; var start: UInt32; var end: UInt32; var hash: Data }
    private var regions: [UInt8: RegionInfo] = [:]

    // Synchronization
    private let queue = DispatchQueue(label: "PartialFlashingManager.queue")

    init(peripheral: CBPeripheral) {
        super.init()
        self.peripheral = peripheral
        peripheral.delegate = self
    }

    // MARK: - Capability check
    static func isLikelyV3(advertisedServices: [CBUUID]) -> Bool {
        return advertisedServices.contains(partialFlashingServiceUUID) || advertisedServices.contains(secureDFUServiceUUID)
    }

    // MARK: - Discovery
    func beginServiceDiscovery() {
        guard let peripheral = peripheral else { return }
        peripheral.discoverServices([Self.partialFlashingServiceUUID, Self.secureDFUServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error { onError?(error); return }
        guard let services = peripheral.services, !services.isEmpty else { return }
        for service in services where service.uuid == Self.partialFlashingServiceUUID {
            peripheral.discoverCharacteristics([Self.partialFlashingCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error { onError?(error); return }
        guard let characteristics = service.characteristics else { return }
        for c in characteristics where c.uuid == Self.partialFlashingCharacteristicUUID {
            pfCharacteristic = c
            peripheral.setNotifyValue(true, for: c)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { onError?(error); return }
        guard characteristic.uuid == Self.partialFlashingCharacteristicUUID else { return }
        if characteristic.isNotifying { onReadyForPartialFlash?() }
    }

    // MARK: - Notifications (Region info and flash acks)
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { onError?(error); return }
        guard characteristic.uuid == Self.partialFlashingCharacteristicUUID, let data = characteristic.value else { return }
        parsePFNotification(data)
    }

    private func parsePFNotification(_ data: Data) {
        guard let command = data.first else { return }
        switch command {
        case Command.regionInfo.rawValue:
            // Payload: [cmd, regionID, start(4 LE), end(4 LE), hash(8 bytes)]
            guard data.count >= 1 + 1 + 4 + 4 + 8 else { return }
            let regionID = data[1]
            let start = data.subdata(in: 2..<6).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
            let end = data.subdata(in: 6..<10).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
            let hash = data.subdata(in: 10..<18)
            regions[regionID] = RegionInfo(id: regionID, start: start, end: end, hash: hash)
        case Command.flash.rawValue:
            // Packet state handled in flashing loop (not implemented here)
            break
        default:
            break
        }
    }

    // MARK: - Memory Map
    func requestMemoryMap(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self = self, let peripheral = self.peripheral, let pf = self.pfCharacteristic else { completion(false); return }
            let group = DispatchGroup()
            var ok = true
            for region: UInt8 in 0...2 {
                group.enter()
                var payload = Data(); payload.append(Command.regionInfo.rawValue); payload.append(region)
                peripheral.writeValue(payload, for: pf, type: .withResponse)
                self.queue.asyncAfter(deadline: .now() + 0.25) {
                    if self.regions[region] == nil { ok = false }
                    group.leave()
                }
            }
            group.notify(queue: self.queue) { completion(ok) }
        }
    }

    // MARK: - HEX parsing (MakeCode & MicroPython)
    private struct HexPos { var line: Int; var part: Int; var sizeBytes: Int }

    func startPartialFlash(hexFileURL: URL) {
        // Orchestrate: read memory map, parse file, validate DAL hash and code region positions.
        requestMemoryMap { [weak self] ok in
            guard let self = self else { return }
            guard ok else {
                self.onError?(NSError(domain: "PartialFlashing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read memory map"]))
                return
            }
            do {
                let hex = try HexUtils(url: hexFileURL)
                // Try MakeCode first
                var python = false
                var fileHash: Data? = nil
                var dataPos: HexPos? = try self.findMakeCodeData(hex: hex, fileHashOut: &fileHash)
                if dataPos == nil {
                    dataPos = try self.findPythonData(hex: hex, fileHashOut: &fileHash)
                    python = (dataPos != nil)
                }
                guard let pos = dataPos, let fileHash = fileHash else {
                    self.onError?(NSError(domain: "PartialFlashing", code: -2, userInfo: [NSLocalizedDescriptionKey: "No partial flash data found in HEX"]))
                    return
                }
                // Validate memory map (use Region 1 for DAL hash when python==false, or per Android logic)
                // Regions: 0=SD, 1=DAL, 2=MAKECODE
                guard let dalRegion = self.regions[1] else {
                    self.onError?(NSError(domain: "PartialFlashing", code: -3, userInfo: [NSLocalizedDescriptionKey: "DAL region not reported by device"]))
                    return
                }
                let deviceHash = dalRegion.hash // 8 bytes
                if deviceHash != fileHash {
                    self.onError?(NSError(domain: "PartialFlashing", code: -4, userInfo: [NSLocalizedDescriptionKey: "DAL hash mismatch; need full DFU"]))
                    return
                }
                // Validate code region bounds using Region 2 (MAKECODE)
                if let makecode = self.regions[2] {
                    // Compute file code start address
                    let hdrAddr = try self.hexPosToAddress(hex: hex, pos: pos)
                    let fileStart = hdrAddr + UInt32(pos.part / 2)
                    // The Android flow compares code_startAddress with first packet address (addr0)
                    // We ensure fileStart matches device reported start (allow exact match only for now)
                    guard fileStart == makecode.start else {
                        self.onError?(NSError(domain: "PartialFlashing", code: -5, userInfo: [NSLocalizedDescriptionKey: "Code start address mismatch"]))
                        return
                    }
                }
                // Parsing succeeded
                self.onProgress?(5)
                self.onCompleted?()
            } catch {
                self.onError?(error)
            }
        }
    }

    // MARK: - MakeCode parsing
    private func findMakeCodeData(hex: HexUtils, fileHashOut: inout Data?) throws -> HexPos? {
        let lineOpt1 = try? hex.searchForData(Self.PXT_MAGIC)
        guard let line = lineOpt1 else { return nil }
        let magicData = try hex.getDataFromIndex(line)
        guard let range = magicData.range(of: Self.PXT_MAGIC) else { return nil }
        let partOffset = magicData.distance(from: magicData.startIndex, to: range.lowerBound)
        let pos = HexPos(line: line, part: partOffset, sizeBytes: 0)
        let hdrAddress = try hexPosToAddress(hex: hex, pos: pos)
        let hashAddress = hdrAddress + UInt32(Self.PXT_MAGIC.count / 2)
        let hashPosOpt: HexPos?
        do {
            hashPosOpt = try hexAddressToPos(hex: hex, address: hashAddress)
        } catch {
            return nil
        }
        guard let hashPos = hashPosOpt else { return nil }
        var sizedHashPos = hashPos
        sizedHashPos.sizeBytes = 8
        let fileHashHex = try hexGetData(hex: hex, pos: sizedHashPos)
        guard fileHashHex.count >= 16 else { return nil }
        fileHashOut = Data(hexString: fileHashHex)
        return pos
    }

    // MARK: - MicroPython parsing
    private static let PYTHON_HEADER_SIZE = 16
    private static let PYTHON_REGION_SIZE = 16

    private func findPythonData(hex: HexUtils, fileHashOut: inout Data?) throws -> HexPos? {
        let lineOpt2 = try? hex.searchForDataRegex(Self.UPY_MAGIC_REGEX)
        guard let line = lineOpt2 else { return nil }
        let headerLineData = try hex.getDataFromIndex(line)
        guard let partIdx = headerLineData.range(of: Self.UPY_MAGIC1)?.lowerBound else { return nil }
        let part = headerLineData.distance(from: headerLineData.startIndex, to: partIdx)
        var pos = HexPos(line: line, part: part, sizeBytes: Self.PYTHON_HEADER_SIZE)
        let header = try hexGetData(hex: hex, pos: pos)
        guard header.count >= Self.PYTHON_HEADER_SIZE * 2 else { return nil }
        let version = header.hexToUInt16(at: 8)
        let tableLen = header.hexToUInt16(at: 12)
        let numReg = header.hexToUInt16(at: 16)
        let pageLog2 = header.hexToUInt16(at: 20)
        guard version == 1 else { return nil }
        guard tableLen == numReg * 16 else { return nil }
        let page = 0x1000 // v3/micro:bit v2 page size per Android logic
        guard (1 << pageLog2) == page else { return nil }

        var codeStart: UInt32 = 0
        var codeLength: UInt32 = 0
        var appHash: Data? = nil

        let hdrAddress = try hexPosToAddress(hex: hex, pos: pos)
        for regionIndex in 0..<numReg {
            let regionAddress = hdrAddress &- UInt32(tableLen) &+ UInt32(regionIndex * Self.PYTHON_REGION_SIZE)
            let rposOpt: HexPos?
            do {
                rposOpt = try hexAddressToPos(hex: hex, address: regionAddress)
            } catch {
                return nil
            }
            guard var rpos = rposOpt else { return nil }
            rpos.sizeBytes = Self.PYTHON_REGION_SIZE
            let region = try hexGetData(hex: hex, pos: rpos)
            guard region.count >= Self.PYTHON_REGION_SIZE * 2 else { return nil }
            let regionID = region.hexToUInt8(at: 0)
            let hashType = region.hexToUInt8(at: 2)
            let startPage = region.hexToUInt16(at: 4)
            let length = region.hexToUInt32(at: 8)
            let hashPtr = region.hexToUInt32(at: 16)
            let hash = region.substring(with: 16..<32)

            var regionHash: Data? = nil
            switch hashType {
            case 0:
                regionHash = Data()
            case 1:
                regionHash = Data(hexString: hash)
            case 2:
                // hash is CRC32 of a C-string pointed by hashPtr (up to 100 chars)
                let hposOpt: HexPos?
                do {
                    hposOpt = try hexAddressToPos(hex: hex, address: hashPtr)
                } catch {
                    return nil
                }
                guard var hpos = hposOpt else { return nil }
                hpos.sizeBytes = 100
                let hashDataHex = try hexGetData(hex: hex, pos: hpos)
                var bytes: [UInt8] = []
                bytes.reserveCapacity(100)
                var idx = 0
                while idx < hashDataHex.count/2 {
                    let v = hashDataHex.hexToUInt8(at: idx*2)
                    if v == 0 { break }
                    bytes.append(v)
                    idx += 1
                }
                let crc = CRC32.compute(bytes)
                let le = withUnsafeBytes(of: crc.littleEndian) { Data($0) }
                var padded = Data(count: 8)
                padded.replaceSubrange(0..<min(8, le.count), with: le)
                regionHash = padded
            default:
                return nil
            }

            switch regionID {
            case 2: // micropython app
                appHash = regionHash
            case 3: // file system
                codeStart = UInt32(startPage) &* UInt32(page)
                codeLength = length
            default:
                break
            }
        }

        guard codeStart > 0, codeLength > 0 else { return nil }
        do {
            _ = try hex.searchForAddress(address: UInt32(codeStart))
        } catch {
            return nil
        }
        let pos2Opt: HexPos?
        do {
            pos2Opt = try hexAddressToPos(hex: hex, address: UInt32(codeStart))
        } catch {
            return nil
        }
        guard var pos2 = pos2Opt else { return nil }
        pos2.sizeBytes = Int(codeLength)
        fileHashOut = appHash
        return pos2
    }

    // MARK: - Helpers (HEX operations)
    private func hexPosToAddress(hex: HexUtils, pos: HexPos) throws -> UInt32 {
        let addrLo = try hex.getRecordAddress(fromIndex: pos.line)
        let addrHi = try hex.getSegmentAddress(fromIndex: pos.line)
        let addr = UInt32(addrLo) + UInt32(addrHi) * 256 * 256
        return addr + UInt32(pos.part / 2)
    }

    private func hexAddressToPos(hex: HexUtils, address: UInt32) throws -> HexPos? {
        let lineOpt = try? hex.searchForAddress(address: address)
        guard let line = lineOpt else { return nil }
        let lineAddr = try hex.getRecordAddress(fromIndex: line)
        let addressLo = address % 0x10000
        let offset = Int(addressLo) - Int(lineAddr)
        return HexPos(line: line, part: max(0, offset * 2), sizeBytes: 0)
    }

    private func hexGetData(hex: HexUtils, pos: HexPos) throws -> String {
        var data = ""
        var line = pos.line
        var part = pos.part
        var size = pos.sizeBytes * 2
        while size > 0 {
            let type = try hex.getRecordType(fromIndex: line)
            if type != 0 && type != 0x0D {
                line += 1; part = 0
            } else {
                let lineData = try hex.getDataFromIndex(line)
                let len = lineData.count
                let chunk = min(len - part, size)
                if chunk > 0 {
                    let start = lineData.index(lineData.startIndex, offsetBy: part)
                    let end = lineData.index(start, offsetBy: chunk)
                    data.append(String(lineData[start..<end]))
                    part += chunk; size -= chunk
                }
                if size > 0 && part >= len {
                    line += 1; part = 0
                    let totalLines = (try? hex.numOfLines()) ?? 0
                    if line >= totalLines { break }
                }
            }
        }
        return data
    }
}

// MARK: - Minimal Intel HEX reader used for parsing
private final class HexUtils {
    private struct Record { let type: Int; let address: Int; let segmentHi: Int; let data: String }
    private var records: [Record] = []

    init(url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        try parse(text: text)
    }

    private func parse(text: String) throws {
        var currentSegment: Int = 0
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix(":"), line.count >= 11 else { continue }
            // :LLAAAATT[DD...]CC
            let count = Int(line.hexSubstring(1, 2))
            let addr  = Int(line.hexSubstring(3, 4))
            let type  = Int(line.hexSubstring(7, 2))
            let dataStart = 9
            let dataLen = max(0, min(count * 2, line.count - dataStart - 2))
            let dataStr = String(line[line.index(line.startIndex, offsetBy: dataStart)..<line.index(line.startIndex, offsetBy: dataStart + dataLen)])
            if type == 0x04 { // Extended Linear Address
                currentSegment = Int(line.hexSubstring(9, 4))
            }
            let rec = Record(type: type, address: addr, segmentHi: currentSegment, data: dataStr)
            records.append(rec)
        }
    }

    func numOfLines() throws -> Int { records.count }
    func getRecordType(fromIndex i: Int) throws -> Int { records[i].type }
    func getRecordAddress(fromIndex i: Int) throws -> Int { records[i].address }
    func getSegmentAddress(fromIndex i: Int) throws -> Int { records[i].segmentHi }
    func getDataFromIndex(_ i: Int) throws -> String { records[i].data }

    func searchForData(_ hexPattern: String) throws -> Int? {
        for (i, r) in records.enumerated() where r.type == 0 { if r.data.contains(hexPattern) { return i } }
        return nil
    }

    func searchForDataRegex(_ regex: String) throws -> Int? {
        let re = try NSRegularExpression(pattern: regex)
        for (i, r) in records.enumerated() where r.type == 0 {
            let range = NSRange(location: 0, length: r.data.utf16.count)
            if re.firstMatch(in: r.data, options: [], range: range) != nil { return i }
        }
        return nil
    }

    func searchForAddress(address: UInt32) throws -> Int? {
        for (i, r) in records.enumerated() where r.type == 0 {
            let full = UInt32(r.address) + UInt32(r.segmentHi) * 256 * 256
            if address >= full && address < full + UInt32(r.data.count/2) { return i }
        }
        return nil
    }
}

// MARK: - Utilities
private extension String {
    func hexSubstring(_ start: Int, _ length: Int) -> UInt32 {
        let s = index(startIndex, offsetBy: start)
        let e = index(s, offsetBy: length)
        return UInt32(self[s..<e], radix: 16) ?? 0
    }

    func hexToUInt8(at idx: Int) -> UInt8 {
        let s = index(startIndex, offsetBy: idx)
        let e = index(s, offsetBy: 2)
        return UInt8(self[s..<e], radix: 16) ?? 0
    }

    func hexToUInt16(at idx: Int) -> Int {
        let lo = Int(hexToUInt8(at: idx))
        let hi = Int(hexToUInt8(at: idx + 2))
        return hi * 256 + lo
    }

    func hexToUInt32(at idx: Int) -> UInt32 {
        let b0 = UInt32(hexToUInt8(at: idx))
        let b1 = UInt32(hexToUInt8(at: idx + 2))
        let b2 = UInt32(hexToUInt8(at: idx + 4))
        let b3 = UInt32(hexToUInt8(at: idx + 6))
        return b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
    }

    func substring(with range: Range<Int>) -> String {
        let s = index(startIndex, offsetBy: range.lowerBound)
        let e = index(startIndex, offsetBy: range.upperBound)
        return String(self[s..<e])
    }
}

private extension Data {
    init?(hexString: String) {
        let len = hexString.count
        guard len % 2 == 0 else { return nil }
        var data = Data(capacity: len/2)
        var idx = hexString.startIndex
        while idx < hexString.endIndex {
            let next = hexString.index(idx, offsetBy: 2)
            let byteStr = hexString[idx..<next]
            guard let b = UInt8(byteStr, radix: 16) else { return nil }
            data.append(b)
            idx = next
        }
        self = data
    }
}

private enum CRC32 {
    static func compute(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in bytes {
            var x = (crc ^ UInt32(b)) & 0xFF
            for _ in 0..<8 { x = (x & 1) != 0 ? (0xEDB88320 ^ (x >> 1)) : (x >> 1) }
            crc = (crc >> 8) ^ x
        }
        return crc ^ 0xFFFFFFFF
    }
}

