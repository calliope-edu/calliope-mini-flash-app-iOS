import Foundation

// MARK: - Partial Flash Manager

/// Manages partial flashing functionality including hash tracking, hex filtering, and data iteration
struct PartialFlashManager {
        // MARK: - Settings Integration
        /// Returns true if partial flashing is enabled in iOS settings
        static var isPartialFlashingEnabled: Bool {
            UserDefaults.standard.object(forKey: "partialFlashingEnabled") as? Bool ?? true
        }
    
    
    // MARK: - Cache Management
    
    /// Cache filtered hex to avoid re-filtering on every call
    private static var filteredHexCache: [URL: URL] = [:]
    private static let cacheLock = NSLock()
    
    /// Clears all cached filtered hex files
    static func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        filteredHexCache.removeAll()
    }
    
    /// Get cached filtered URL for a hex file
    static func getCachedFilteredURL(for url: URL) -> URL? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return filteredHexCache[url]
    }
    
    /// Cache filtered URL for a hex file
    static func setCachedFilteredURL(_ filteredURL: URL, for url: URL) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        filteredHexCache[url] = filteredURL
    }
    
    // MARK: - Partial Flash Info Retrieval
    
    /// Retrieves partial flashing information from hex file
    /// Uses original hex to find magic markers and extract hashes, then uses filtered hex for data
    /// - Parameter url: URL of the hex file
    /// - Returns: Tuple of (fileHash, programHash, partialFlashData) or nil if not a MakeCode file
    static func retrievePartialFlashingInfo(from url: URL) -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
                // Check if partial flashing is enabled in settings
                guard isPartialFlashingEnabled else {
                    return nil
                }
        // Step 1: Extract hashes from original hex
        guard let hashInfo = extractHashes(from: url) else {
            return nil
        }
        
        // Step 2: Get or create filtered hex for data transmission (for speed)
        let filteredURL: URL
        if let cached = getCachedFilteredURL(for: url) {
            filteredURL = cached
        } else if let lines = UniversalHexFilter.filterUniversalHex(sourceURL: url, hexBlock: .v2),
                  let newURL = UniversalHexFilter.writeFilteredHex(lines) {
            setCachedFilteredURL(newURL, for: url)
            filteredURL = newURL
        } else {
            filteredURL = url
        }
        
        // Step 3: Create PartialFlashData from filtered hex (fallback to original if needed)
        guard let partialData = createPartialFlashData(from: filteredURL) ?? createPartialFlashData(from: url) else {
            return nil
        }
        // If too many packets, fall back to full DFU
        if partialData.lineCount > 700 {
            return nil
        }
        return (hashInfo.fileHash, hashInfo.programHash, partialData)
    }
    
    // MARK: - Hash Extraction
    
    /// Extract hashes from hex file without creating PartialFlashData
    /// - Parameter url: URL of the hex file
    /// - Returns: Tuple of (fileHash/DAL hash, programHash) or nil if no magic marker found
    static func extractHashes(from url: URL) -> (fileHash: Data, programHash: Data)? {
        guard let reader = StreamReader(path: url.path) else {
            return nil
        }
        defer { reader.close() }
        
        let (magicLine, _) = forwardToMagicNumber(reader)
        guard magicLine != nil else {
            return nil
        }
        
        // Read hash line immediately after magic
        guard let hashesLine = reader.nextLine() else {
            return nil
        }
        
        // Validate hash line format
        let hashRecordType = PartialFlashHexReader.type(of: hashesLine)
        let hashRecordLength = PartialFlashHexReader.length(of: hashesLine)
        
        guard hashRecordType == 0, hashRecordLength == 16 else {
            return nil
        }
        
        guard hashesLine.count >= 41,
              let templateHash = hashesLine[9..<25].toData(using: .hex),
              let programHash = (hashesLine[25..<41]).toData(using: .hex) else {
            return nil
        }
        
        return (templateHash, programHash)
    }
    
    // MARK: - PartialFlashData Creation
    
    /// Create PartialFlashData from a hex file URL
    /// - Parameter url: URL of the hex file (original or filtered)
    /// - Returns: PartialFlashData iterator or nil if no magic marker found
    static func createPartialFlashData(from url: URL) -> PartialFlashData? {
        guard let reader = StreamReader(path: url.path) else {
            return nil
        }
        
        let (magicLine, _) = forwardToMagicNumber(reader)
        guard magicLine != nil else {
            return nil
        }
        
        // Read hash line
        guard let hashesLine = reader.nextLine() else {
            return nil
        }
        
        // Count lines from current position to magic end
        var numLinesToFlash = 0
        while let line = reader.nextLine() {
            if PartialFlashHexReader.isEndOfFileOrMagicEnd(line) {
                break
            }
            if line.starts(with: ":") && PartialFlashHexReader.type(of: line) == 0 {
                if let data = PartialFlashHexReader.readData(line), !data.data.allSatisfy({ $0 == 0xFF }) {
                    numLinesToFlash += 1
                }
            }
        }
        
        // Open fresh reader for data transmission
        guard let freshReader = StreamReader(path: url.path) else {
            return nil
        }
        
        let (freshMagicLine, freshSegmentAddress) = forwardToMagicNumber(freshReader)
        guard let freshMagicLine = freshMagicLine else {
            return nil
        }
        
        guard let hashesLineForData = freshReader.nextLine() else {
            return nil
        }
        
        return PartialFlashData(
            nextLines: [hashesLineForData, freshMagicLine],
            currentSegmentAddress: freshSegmentAddress,
            reader: freshReader,
            lineCount: numLinesToFlash)
    }
    
    // MARK: - Magic Marker Detection
    
    /// Forward reader to magic marker, tracking ELA segments
    /// - Parameter reader: StreamReader positioned at start of hex file
    /// - Returns: Tuple of (magic line or nil, current segment address)
    private static func forwardToMagicNumber(_ reader: StreamReader) -> (String?, UInt16) {
        var magicLine: String?
        var currentSegmentAddress: UInt16 = 0
        
        while let record = reader.nextLine() {
            // Track ELA (type 04) segment changes
            if PartialFlashHexReader.type(of: record) == 4,
               let length = PartialFlashHexReader.length(of: record), length == 2,
               let data = PartialFlashHexReader.data(of: record, length) {
                currentSegmentAddress = (UInt16(data[0]) << 8) | UInt16(data[1])
                continue
            }
            
            // Check for magic marker with address validation
            if PartialFlashHexReader.isMagicStart(record) {
                let recordAddress = PartialFlashHexReader.address(of: record) ?? 0
                let absoluteAddress = UInt32(currentSegmentAddress) << 16 | UInt32(recordAddress)
                
                // Valid magic marker addresses: 0x47000, 0x77000 (V3), 0x1F000 (V1/V2)
                if [0x47000, 0x77000, 0x1F000].contains(absoluteAddress) {
                    magicLine = record
                    break
                }
            }
        }
        return (magicLine, currentSegmentAddress)
    }
}

// MARK: - Partial Flash Data Iterator

/// Iterator for partial flash data packets
/// Reads hex data from magic marker to magic end, skipping empty (0xFF) blocks
struct PartialFlashData: Sequence, IteratorProtocol {
    typealias Element = (address: UInt16, data: Data)

    public let lineCount: Int
    public private(set) var currentSegmentAddress: UInt16
    private var nextData: [(address: UInt16, data: Data)] = []
    private var reader: StreamReader?
    private var skippedCount: Int = 0

    init(nextLines: [String], currentSegmentAddress: UInt16, reader: StreamReader, lineCount: Int) {
        self.reader = reader
        self.nextData = []
        self.currentSegmentAddress = currentSegmentAddress
        self.lineCount = lineCount
        // Extract data from initial lines
        nextLines.forEach { read($0) }
    }

    mutating func next() -> (address: UInt16, data: Data)? {
        // Skip empty blocks (only 0xFF) like Android does
        while true {
            let line = nextData.popLast()
            while let reader = reader, nextData.count == 0 {
                guard let record = reader.nextLine() else {
                    break
                }
                read(record)
            }
            
            guard let result = line else {
                return nil
            }
            
            // Skip empty blocks (all 0xFF = erased flash)
            if result.data.allSatisfy({ $0 == 0xFF }) {
                skippedCount += 1
                continue
            }
            
            return result
        }
    }

    mutating private func read(_ record: String) {
        if PartialFlashHexReader.isEndOfFileOrMagicEnd(record) {
            reader?.close()
            reader = nil
            return
        }
        switch PartialFlashHexReader.type(of: record) {
        case 0: // Data record
            if record.contains("00000001FF") {
                break
            } else if let data = PartialFlashHexReader.readData(record) {
                nextData.append(data)
            }
        case 2: // Extended segment address
            if let segmentAddress = PartialFlashHexReader.readSegmentAddress(record) {
                currentSegmentAddress = segmentAddress
            }
        case 4: // Extended linear address
            if let segmentAddress = PartialFlashHexReader.readSegmentAddress(record) {
                currentSegmentAddress = segmentAddress
            }
        default:
            break
        }
    }
}

// MARK: - Partial Flash Hex Reader

/// Helper for reading Intel HEX records during partial flashing
struct PartialFlashHexReader {

    static let MAGIC_START_NUMBER = "708E3B92C615A841C49866C975EE5197"
    static let MAGIC_END_NUMBER = "41140E2FB82FA2B"

    static func readSegmentAddress(_ record: String) -> UInt16? {
        if let length = length(of: record), length == 2,
           validate(record, length),
           let data = data(of: record, length) {
            return UInt16(bigEndianData: data)
        }
        return nil
    }

    static func readData(_ record: String) -> (address: UInt16, data: Data)? {
        if let length = length(of: record),
           validate(record, length),
           let address = address(of: record),
           let data = data(of: record, length) {
            return (address, data)
        }
        return nil
    }

    static func validate(_ record: String, _ length: Int) -> Bool {
        return record.trimmingCharacters(in: .whitespacesAndNewlines).count == 9 + 2 * length + 2
    }

    static func type(of record: String) -> Int? {
        guard record.count >= 9 else { return nil }
        return Int(record[7..<9], radix: 16)
    }

    static func length(of record: String) -> Int? {
        guard record.count >= 3 else { return nil }
        return Int(record[1..<3], radix: 16)
    }

    static func address(of record: String) -> UInt16? {
        guard record.count >= 7 else { return nil }
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

// MARK: - Universal Hex Filter

/// Filters universal hex files to extract only the application region code
/// This reduces partial flash packet count from ~2,300 to ~443 packets
struct UniversalHexFilter {
    
    // Intel HEX record types
    private enum RecordType: UInt8 {
        case data = 0x00
        case endOfFile = 0x01
        case extendedSegmentAddress = 0x02
        case extendedLinearAddress = 0x04
    }
    
    // Application memory regions for different micro:bit versions
    enum HexBlock {
        case v1  // micro:bit V1
        case v2  // micro:bit V2 / Calliope mini
        
        var addressRange: (min: UInt32, max: UInt32, pageSize: UInt32) {
            switch self {
            case .v1:
                return (min: 0x18000, max: 0x3C000, pageSize: 0x400)
            case .v2:
                return (min: 0x1C000, max: 0x77000, pageSize: 0x1000)
            }
        }
    }
    
    /// Filters a universal hex file to extract only application region records
    static func filterUniversalHex(sourceURL: URL, hexBlock: HexBlock) -> [String]? {
        guard let reader = StreamReader(path: sourceURL.path) else {
            return nil
        }
        defer { reader.close() }
        
        let range = hexBlock.addressRange
        var filteredLines: [String] = []
        var currentSegmentAddress: UInt32 = 0
        var lastEmittedSegment: UInt32? = nil
        
        while let line = reader.nextLine() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let record = parseHexRecord(trimmed) else {
                continue
            }
            
            // Update segment address for type 04 (Extended Linear Address)
            if record.type == RecordType.extendedLinearAddress.rawValue {
                currentSegmentAddress = UInt32(record.data[0]) << 24 | UInt32(record.data[1]) << 16
                continue
            }
            
            // Handle type 02 (Extended Segment Address)
            if record.type == RecordType.extendedSegmentAddress.rawValue {
                currentSegmentAddress = (UInt32(record.data[0]) << 8 | UInt32(record.data[1])) << 4
                continue
            }
            
            // Handle data records (type 00) - filter by address range
            if record.type == RecordType.data.rawValue {
                let fullAddress = currentSegmentAddress + UInt32(record.address)
                
                // Check if this record overlaps with application region
                if fullAddress < range.max && fullAddress + UInt32(record.data.count) > range.min {
                    // Emit segment record if needed
                    if lastEmittedSegment != currentSegmentAddress {
                        let segmentHigh16 = (currentSegmentAddress >> 16) & 0xFFFF
                        filteredLines.append(createExtendedLinearAddressRecord(segment: segmentHigh16))
                        lastEmittedSegment = currentSegmentAddress
                    }
                    filteredLines.append(trimmed)
                }
            }
            
            // Include EOF record (type 01)
            if record.type == RecordType.endOfFile.rawValue {
                filteredLines.append(trimmed)
                break
            }
        }
        
        return filteredLines.isEmpty ? nil : filteredLines
    }
    
    /// Writes filtered hex lines to a temporary file
    static func writeFilteredHex(_ lines: [String]) -> URL? {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("application_filtered.hex")
        
        do {
            try lines.joined(separator: "\n").write(to: tempFile, atomically: true, encoding: .utf8)
            return tempFile
        } catch {
            return nil
        }
    }
    
    // MARK: - Helper Functions
    
    private struct HexRecord {
        let address: UInt16
        let type: UInt8
        let data: Data
    }
    
    private static func parseHexRecord(_ line: String) -> HexRecord? {
        guard line.hasPrefix(":"), line.count >= 11 else {
            return nil
        }
        
        let hex = String(line.dropFirst())
        
        guard let byteCount = UInt8(hex.prefix(2), radix: 16),
              let address = UInt16(hex.dropFirst(2).prefix(4), radix: 16),
              let type = UInt8(hex.dropFirst(6).prefix(2), radix: 16) else {
            return nil
        }
        
        var data = Data()
        let dataStart = hex.index(hex.startIndex, offsetBy: 8)
        let dataEnd = hex.index(dataStart, offsetBy: Int(byteCount) * 2)
        let dataHex = String(hex[dataStart..<dataEnd])
        
        for i in stride(from: 0, to: dataHex.count, by: 2) {
            let start = dataHex.index(dataHex.startIndex, offsetBy: i)
            let end = dataHex.index(start, offsetBy: 2)
            if let byte = UInt8(dataHex[start..<end], radix: 16) {
                data.append(byte)
            }
        }
        
        return HexRecord(address: address, type: type, data: data)
    }
    
    private static func createExtendedLinearAddressRecord(segment: UInt32) -> String {
        let byteCount: UInt8 = 0x02
        let address: UInt16 = 0x0000
        let recordType: UInt8 = 0x04
        let dataHigh: UInt8 = UInt8((segment >> 8) & 0xFF)
        let dataLow: UInt8 = UInt8(segment & 0xFF)
        
        let sum = Int(byteCount) + Int(address >> 8) + Int(address & 0xFF) + 
                  Int(recordType) + Int(dataHigh) + Int(dataLow)
        let checksum = UInt8((256 - (sum & 0xFF)) & 0xFF)
        
        return String(format: ":%02X%04X%02X%02X%02X%02X", 
                     byteCount, address, recordType, dataHigh, dataLow, checksum)
    }
}
