import Foundation

// MARK: - Partial Flash Manager

/// Manages partial flashing functionality including hash tracking, hex filtering, and data iteration
struct PartialFlashManager {
        // MARK: - Settings Integration
        /// Returns true if partial flashing is enabled in iOS settings
        static var isPartialFlashingEnabled: Bool {
            // Ensure UserDefaults are synchronized (important when settings changed in Settings app)
            UserDefaults.standard.synchronize()
            
            // Check if key exists first - if not, default to true
            if UserDefaults.standard.object(forKey: "partialFlashingEnabled") == nil {
                return true
            }
            // If key exists, return its boolean value
            return UserDefaults.standard.bool(forKey: "partialFlashingEnabled")
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
        LogNotify.log("[PartialFlash] Starting retrievePartialFlashingInfo for: \(url.lastPathComponent)")
        
        // Check if partial flashing is enabled in settings
        guard isPartialFlashingEnabled else {
            LogNotify.log("[PartialFlash] ❌ Partial flashing disabled in settings - falling back to full DFU")
            return nil
        }
        LogNotify.log("[PartialFlash] ✓ Partial flashing enabled in settings")

        // Step 1: Try MakeCode path (magic marker + inline hashes)
        if let (fileHash, programHash) = extractHashes(from: url) {
            LogNotify.log("[PartialFlash] ✓ MakeCode hashes extracted - fileHash: \(fileHash.hexEncodedString()), programHash: \(programHash.hexEncodedString())")
            return retrieveMakeCodePartialFlashingInfo(from: url, fileHash: fileHash, programHash: programHash)
        }

        // Step 2: Try MicroPython path (region table with CRC32 hash)
        LogNotify.log("[PartialFlash] No MakeCode magic found, checking for MicroPython...")
        return retrieveMicroPythonPartialFlashingInfo(from: url)
    }

    private static func retrieveMakeCodePartialFlashingInfo(from url: URL, fileHash: Data, programHash: Data) -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
        // Get or create filtered hex for data transmission (for speed)
        let filteredURL: URL
        if let cached = getCachedFilteredURL(for: url) {
            LogNotify.log("[PartialFlash] ✓ Using cached filtered hex")
            filteredURL = cached
        } else if let lines = UniversalHexFilter.filterUniversalHex(sourceURL: url, hexBlock: .v2),
                  let newURL = UniversalHexFilter.writeFilteredHex(lines) {
            LogNotify.log("[PartialFlash] ✓ Created new filtered hex (\(lines.count) lines)")
            setCachedFilteredURL(newURL, for: url)
            filteredURL = newURL
        } else {
            LogNotify.log("[PartialFlash] ⚠️ Filtering failed, using original hex")
            filteredURL = url
        }

        // Create PartialFlashData from filtered hex (fallback to original if needed)
        guard let partialData = createPartialFlashData(from: filteredURL) ?? createPartialFlashData(from: url) else {
            LogNotify.log("[PartialFlash] ❌ Failed to create PartialFlashData - falling back to full DFU")
            return nil
        }

        LogNotify.log("[PartialFlash] ✓ MakeCode PartialFlashData created with \(partialData.lineCount) lines")
        // V3 has ~443 packets, V1/V2 has ~1348 packets - both are worthwhile vs full DFU
        if partialData.lineCount > 2000 {
            LogNotify.log("[PartialFlash] ❌ Too many packets (\(partialData.lineCount) > 2000) - falling back to full DFU")
            return nil
        }

        LogNotify.log("[PartialFlash] ✅ MakeCode partial flashing approved")
        return (fileHash, programHash, partialData)
    }
    
    // MARK: - Hash Extraction
    
    /// Extract hashes from hex file without creating PartialFlashData
    /// - Parameter url: URL of the hex file
    /// - Returns: Tuple of (fileHash/DAL hash, programHash) or nil if no magic marker found
    static func extractHashes(from url: URL) -> (fileHash: Data, programHash: Data)? {
        guard let reader = StreamReader(path: url.path) else {
            LogNotify.log("[PartialFlash] extractHashes: Failed to create StreamReader")
            return nil
        }
        defer { reader.close() }
        
        let (magicLine, _, codeStartAddr) = forwardToMagicNumber(reader)
        guard magicLine != nil else {
            LogNotify.log("[PartialFlash] extractHashes: No magic marker found in hex file")
            return nil
        }
        LogNotify.log("[PartialFlash] extractHashes: Magic marker found at address 0x\(String(codeStartAddr, radix: 16))")
        
        // Read hash line immediately after magic
        guard let hashesLine = reader.nextLine() else {
            LogNotify.log("[PartialFlash] extractHashes: Failed to read hash line after magic marker")
            return nil
        }
        
        // Validate hash line format
        let hashRecordType = PartialFlashHexReader.type(of: hashesLine)
        let hashRecordLength = PartialFlashHexReader.length(of: hashesLine)
        
        guard hashRecordType == 0, hashRecordLength == 16 else {
            LogNotify.log("[PartialFlash] extractHashes: Invalid hash line format (type=\(hashRecordType ?? -1), length=\(hashRecordLength ?? -1))")
            return nil
        }
        
        guard hashesLine.count >= 41,
              let templateHash = hashesLine[9..<25].toData(using: .hex),
              let programHash = (hashesLine[25..<41]).toData(using: .hex) else {
            LogNotify.log("[PartialFlash] extractHashes: Failed to parse hashes from line (length=\(hashesLine.count))")
            return nil
        }
        
        LogNotify.log("[PartialFlash] extractHashes: Successfully parsed hashes")
        return (templateHash, programHash)
    }
    
    // MARK: - PartialFlashData Creation
    
    /// Create PartialFlashData from a hex file URL
    /// - Parameter url: URL of the hex file (original or filtered)
    /// - Returns: PartialFlashData iterator or nil if no magic marker found
    static func createPartialFlashData(from url: URL) -> PartialFlashData? {
        LogNotify.log("[PartialFlash] createPartialFlashData: Processing \(url.lastPathComponent)")
        guard let reader = StreamReader(path: url.path) else {
            LogNotify.log("[PartialFlash] createPartialFlashData: Failed to create StreamReader")
            return nil
        }
        
        let (magicLine, _, _) = forwardToMagicNumber(reader)
        guard magicLine != nil else {
            LogNotify.log("[PartialFlash] createPartialFlashData: No magic marker found")
            return nil
        }
        
        // Read hash line
        guard let hashesLine = reader.nextLine() else {
            LogNotify.log("[PartialFlash] createPartialFlashData: Failed to read hash line")
            return nil
        }
        
        // Count lines from current position to magic end
        var numLinesToFlash = 0
        var totalLines = 0
        while let line = reader.nextLine() {
            if PartialFlashHexReader.isEndOfFileOrMagicEnd(line) {
                break
            }
            if line.starts(with: ":") && PartialFlashHexReader.type(of: line) == 0 {
                totalLines += 1
                if let data = PartialFlashHexReader.readData(line), !data.data.allSatisfy({ $0 == 0xFF }) {
                    numLinesToFlash += 1
                }
            }
        }
        LogNotify.log("[PartialFlash] createPartialFlashData: Counted \(numLinesToFlash) non-empty lines out of \(totalLines) total data lines")
        
        // Open fresh reader for data transmission
        guard let freshReader = StreamReader(path: url.path) else {
            LogNotify.log("[PartialFlash] createPartialFlashData: Failed to create fresh StreamReader")
            return nil
        }
        
        let (freshMagicLine, freshSegmentAddress, codeStart) = forwardToMagicNumber(freshReader)
        guard let freshMagicLine = freshMagicLine else {
            LogNotify.log("[PartialFlash] createPartialFlashData: Failed to find magic marker in fresh reader")
            return nil
        }
        
        guard let hashesLineForData = freshReader.nextLine() else {
            LogNotify.log("[PartialFlash] createPartialFlashData: Failed to read hash line in fresh reader")
            return nil
        }
        
        LogNotify.log("[PartialFlash] createPartialFlashData: Successfully created PartialFlashData iterator")
        return PartialFlashData(
            nextLines: [hashesLineForData, freshMagicLine],
            currentSegmentAddress: freshSegmentAddress,
            codeStartAddress: codeStart,
            reader: freshReader,
            lineCount: numLinesToFlash)
    }
    
    // MARK: - Magic Marker Detection
    
    /// Forward reader to magic marker, tracking ELA segments
    /// - Parameter reader: StreamReader positioned at start of hex file
    /// - Returns: Tuple of (magic line or nil, current segment address, code start address)
    private static func forwardToMagicNumber(_ reader: StreamReader) -> (String?, UInt16, UInt32) {
        var magicLine: String?
        var currentSegmentAddress: UInt16 = 0
        var codeStartAddress: UInt32 = 0
        var lineCount = 0
        
        while let record = reader.nextLine() {
            lineCount += 1
            // Track ELA (type 04) segment changes
            if PartialFlashHexReader.type(of: record) == 4,
               let length = PartialFlashHexReader.length(of: record), length == 2,
               let data = PartialFlashHexReader.data(of: record, length) {
                currentSegmentAddress = (UInt16(data[0]) << 8) | UInt16(data[1])
                continue
            }
            
            // Check for magic marker pattern (accept at any address, like Android implementation)
            if PartialFlashHexReader.isMagicStart(record) {
                let recordAddress = PartialFlashHexReader.address(of: record) ?? 0
                let absoluteAddress = UInt32(currentSegmentAddress) << 16 | UInt32(recordAddress)
                
                LogNotify.log("[PartialFlash] forwardToMagicNumber: Found magic marker at 0x\(String(absoluteAddress, radix: 16)) on line \(lineCount)")
                magicLine = record
                codeStartAddress = absoluteAddress
                break
            }
        }
        
        if magicLine == nil {
            LogNotify.log("[PartialFlash] forwardToMagicNumber: Scanned \(lineCount) lines, no magic marker pattern found (looking for \(PartialFlashHexReader.MAGIC_START_NUMBER))")
        }
        
        return (magicLine, currentSegmentAddress, codeStartAddress)
    }

    // MARK: - MicroPython Support

    private struct MicroPythonInfo {
        let dalHash: Data
        let codeStart: UInt32
        let codeLength: UInt32
    }

    /// Retrieve partial flashing info for a MicroPython hex file.
    private static func retrieveMicroPythonPartialFlashingInfo(from url: URL) -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
        guard let info = extractMicroPythonInfo(from: url) else {
            LogNotify.log("[PartialFlash] ❌ Not a MicroPython hex file")
            return nil
        }

        LogNotify.log("[PartialFlash] ✓ MicroPython detected - dalHash: \(info.dalHash.hexEncodedString()), codeStart: 0x\(String(info.codeStart, radix: 16)), length: \(info.codeLength)")

        guard let partialData = createMicroPythonPartialFlashData(from: url, startAddress: info.codeStart, codeLength: info.codeLength) else {
            LogNotify.log("[PartialFlash] ❌ Failed to create MicroPython PartialFlashData")
            return nil
        }

        if partialData.lineCount > 2000 {
            LogNotify.log("[PartialFlash] ❌ Too many MicroPython packets (\(partialData.lineCount) > 2000) - falling back to full DFU")
            return nil
        }

        LogNotify.log("[PartialFlash] ✅ MicroPython partial flashing approved (\(partialData.lineCount) lines)")
        // programHash is not used for MicroPython (device program hash will be zero — expected)
        return (info.dalHash, info.dalHash, partialData)
    }

    /// Parse the MicroPython region table from a hex file.
    /// Builds a flat byte map for random-access reads (needed for region table + hash pointer).
    /// Returns DAL hash, filesystem code start address, and length — or nil if not MicroPython.
    private static func extractMicroPythonInfo(from url: URL) -> MicroPythonInfo? {
        guard let reader = StreamReader(path: url.path) else { return nil }
        defer { reader.close() }

        var dataMap: [UInt32: UInt8] = [:]
        var currentSegment: UInt32 = 0
        var headerAbsAddress: UInt32? = nil

        while let line = reader.nextLine() {
            guard let recType = PartialFlashHexReader.type(of: line) else { continue }

            if recType == 4,
               let len = PartialFlashHexReader.length(of: line), len == 2,
               let segData = PartialFlashHexReader.data(of: line, len) {
                currentSegment = (UInt32(segData[0]) << 24) | (UInt32(segData[1]) << 16)
                continue
            }

            // type 0 = data, type 0x0D = micro:bit universal hex Block Start (also contains raw data)
            if (recType == 0 || recType == 0x0D),
               let len = PartialFlashHexReader.length(of: line),
               let addr = PartialFlashHexReader.address(of: line),
               let recData = PartialFlashHexReader.data(of: line, len) {
                let absAddr = currentSegment | UInt32(addr)
                for (i, byte) in recData.enumerated() {
                    dataMap[absAddr + UInt32(i)] = byte
                }
                // Detect the MicroPython header (both magic bytes in the same record)
                if headerAbsAddress == nil && PartialFlashHexReader.isMicroPythonStart(line) {
                    let dataStr = line[9..<(9 + len * 2)]
                    if let magicRange = dataStr.range(of: PartialFlashHexReader.MICROPYTHON_MAGIC1) {
                        let charOffset = dataStr.distance(from: dataStr.startIndex, to: magicRange.lowerBound)
                        headerAbsAddress = absAddr + UInt32(charOffset / 2)
                    }
                }
            }
        }

        guard let hdrAddr = headerAbsAddress else {
            LogNotify.log("[PartialFlash] extractMicroPythonInfo: No MicroPython header found")
            return nil
        }

        // Byte-level helpers — all region fields are little-endian
        func byte(_ a: UInt32) -> UInt8  { dataMap[a] ?? 0xFF }
        func le16(_ a: UInt32) -> UInt16 { UInt16(byte(a)) | (UInt16(byte(a + 1)) << 8) }
        func le32(_ a: UInt32) -> UInt32 { UInt32(le16(a)) | (UInt32(le16(a + 2)) << 16) }

        // 16-byte header layout at hdrAddr:
        //   bytes  0-3:  magic1 FE307F59
        //   bytes  4-5:  version (LE u16, must be 1)
        //   bytes  6-7:  table_len (LE u16) = num_reg × 16
        //   bytes  8-9:  num_reg (LE u16)
        //   bytes 10-11: pageLog2 (LE u16)  12 = 4 KB pages for Calliope V3
        //   bytes 12-15: magic2 9DD7B1C1
        let version   = le16(hdrAddr + 4)
        let tableLen  = le16(hdrAddr + 6)
        let numReg    = le16(hdrAddr + 8)
        let pageLog2  = le16(hdrAddr + 10)

        guard version == 1 else {
            LogNotify.log("[PartialFlash] MicroPython: invalid version \(version)")
            return nil
        }
        guard tableLen == numReg * 16 else {
            LogNotify.log("[PartialFlash] MicroPython: table_len \(tableLen) != numReg \(numReg) × 16")
            return nil
        }

        let pageSize    = UInt32(1) << pageLog2
        let regionsBase = hdrAddr - UInt32(tableLen)
        LogNotify.log("[PartialFlash] MicroPython header @ 0x\(String(hdrAddr, radix: 16)): version=\(version), numReg=\(numReg), pageSize=0x\(String(pageSize, radix: 16))")

        // 16-byte region entry layout at regAddr:
        //   byte   0:    regionID   (1=softdevice, 2=micropython_app, 3=filesystem)
        //   byte   1:    hashType   (0=none, 1=verbatim 8 bytes, 2=CRC32 of string at ptr)
        //   bytes  2-3:  startPage  (LE u16)
        //   bytes  4-7:  length     (LE u32) — meaningful for filesystem region
        //   bytes  8-11: hashPtr    (LE u32) — pointer to null-terminated string (hashType=2)
        //   bytes  8-15: hashData   (8 bytes) — verbatim hash (hashType=1)
        var dalHash: Data? = nil
        var codeStart: UInt32? = nil
        var codeLength: UInt32? = nil

        for i in 0..<Int(numReg) {
            let regAddr   = regionsBase + UInt32(i * 16)
            let regionID  = byte(regAddr + 0)
            let hashType  = byte(regAddr + 1)
            let startPage = le16(regAddr + 2)
            let length    = le32(regAddr + 4)
            let hashPtr   = le32(regAddr + 8)
            let hashData  = Data((0..<8).map { byte(regAddr + 8 + $0) })

            LogNotify.log("[PartialFlash] Region \(i): id=\(regionID) hashType=\(hashType) startPage=\(startPage) length=\(length)")

            switch regionID {
            case 2: // micropython_app — provides the DAL hash compared against device
                switch hashType {
                case 0:
                    LogNotify.log("[PartialFlash] MicroPython app region has no hash (type=0)")
                    dalHash = Data(repeating: 0, count: 8)
                case 1:
                    dalHash = hashData
                    LogNotify.log("[PartialFlash] MicroPython DAL hash (verbatim): \(hashData.hexEncodedString())")
                case 2:
                    if let hash = computeCRC32Hash(fromAddress: hashPtr, dataMap: dataMap) {
                        dalHash = hash
                        LogNotify.log("[PartialFlash] MicroPython DAL hash (CRC32): \(hash.hexEncodedString())")
                    } else {
                        LogNotify.log("[PartialFlash] MicroPython: failed to compute CRC32 hash")
                        return nil
                    }
                default:
                    LogNotify.log("[PartialFlash] MicroPython: unknown hash type \(hashType) for app region")
                    return nil
                }
            case 3: // filesystem — the region to actually transmit via partial flash
                let start = UInt32(startPage) * pageSize
                codeStart  = start
                codeLength = length
                LogNotify.log("[PartialFlash] Filesystem region: start=0x\(String(start, radix: 16)) length=\(length)")
            default:
                break
            }
        }

        guard let hash = dalHash, let start = codeStart, let len = codeLength, len > 0 else {
            LogNotify.log("[PartialFlash] MicroPython: missing DAL hash or filesystem region")
            return nil
        }

        return MicroPythonInfo(dalHash: hash, codeStart: start, codeLength: len)
    }

    /// Compute CRC32 of a null-terminated ASCII string at the given address in the data map.
    /// Returns the value as an 8-byte little-endian Data, matching Android's ByteBuffer.LITTLE_ENDIAN putLong.
    private static func computeCRC32Hash(fromAddress address: UInt32, dataMap: [UInt32: UInt8]) -> Data? {
        var bytes: [UInt8] = []
        for i in 0..<100 {
            guard let b = dataMap[address + UInt32(i)] else { break }
            if b == 0 { break }
            bytes.append(b)
        }
        guard !bytes.isEmpty else { return nil }
        let versionString = String(bytes: bytes, encoding: .utf8) ?? "<non-utf8>"
        let crc = CRC32.checksum(bytes: bytes)
        LogNotify.log("[PartialFlash] CRC32 input: \"\(versionString)\" -> CRC32=0x\(String(format: "%08X", crc))")
        // Store as LE uint64 (upper 32 bits zero), matching Android's putLong of a 32-bit CRC
        var value = UInt64(crc)
        return Data(bytes: &value, count: 8)
    }

    /// Create a PartialFlashData iterator covering the MicroPython filesystem region.
    /// Performs two passes: one to count non-0xFF lines, one to position the reader.
    private static func createMicroPythonPartialFlashData(from url: URL, startAddress: UInt32, codeLength: UInt32) -> PartialFlashData? {
        let endAddress = startAddress + codeLength

        // --- Count pass: tally non-0xFF data records in [startAddress, endAddress) ---
        guard let countReader = StreamReader(path: url.path) else { return nil }
        var countSegment: UInt32 = 0
        var numLinesToFlash = 0
        while let line = countReader.nextLine() {
            guard let recType = PartialFlashHexReader.type(of: line) else { continue }
            if recType == 4,
               let len = PartialFlashHexReader.length(of: line), len == 2,
               let data = PartialFlashHexReader.data(of: line, len) {
                countSegment = (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16)
                continue
            }
            if (recType == 0 || recType == 0x0D), let addr = PartialFlashHexReader.address(of: line) {
                let absAddr = countSegment | UInt32(addr)
                if absAddr >= endAddress { continue } // skip out-of-range (e.g. V1 universal hex block at 0x10000000+)
                if absAddr >= startAddress,
                   let dataRec = PartialFlashHexReader.readData(line),
                   !dataRec.data.allSatisfy({ $0 == 0xFF }) {
                    numLinesToFlash += 1
                }
            }
        }
        countReader.close()
        LogNotify.log("[PartialFlash] MicroPython filesystem: \(numLinesToFlash) non-empty lines to flash")

        // --- Data pass: position a fresh reader at the first record at/after startAddress ---
        guard let dataReader = StreamReader(path: url.path) else { return nil }
        var dataSegment: UInt32 = 0
        var firstLine: String? = nil
        var segmentAtFirst: UInt16 = 0
        while let line = dataReader.nextLine() {
            guard let recType = PartialFlashHexReader.type(of: line) else { continue }
            if recType == 4,
               let len = PartialFlashHexReader.length(of: line), len == 2,
               let data = PartialFlashHexReader.data(of: line, len) {
                dataSegment = (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16)
                continue
            }
            if (recType == 0 || recType == 0x0D), let addr = PartialFlashHexReader.address(of: line) {
                let absAddr = dataSegment | UInt32(addr)
                if absAddr >= startAddress && absAddr < endAddress {
                    firstLine = line
                    segmentAtFirst = UInt16((dataSegment >> 16) & 0xFFFF)
                    break
                }
            }
        }

        guard let first = firstLine else {
            LogNotify.log("[PartialFlash] MicroPython: could not locate start address 0x\(String(startAddress, radix: 16))")
            dataReader.close()
            return nil
        }

        LogNotify.log("[PartialFlash] MicroPython reader positioned at 0x\(String(format: "%X", UInt32(segmentAtFirst) << 16)), endAddress=0x\(String(endAddress, radix: 16))")

        return PartialFlashData(
            nextLines: [first],
            currentSegmentAddress: segmentAtFirst,
            codeStartAddress: startAddress,
            reader: dataReader,
            lineCount: numLinesToFlash,
            isMicroPython: true,
            endAddress: endAddress
        )
    }
}

// MARK: - Partial Flash Data Iterator

/// Iterator for partial flash data packets
/// Reads hex data from magic marker to magic end, skipping empty (0xFF) blocks
struct PartialFlashData: Sequence, IteratorProtocol {
    typealias Element = (address: UInt16, data: Data)

    public let lineCount: Int
    /// True when this data belongs to a MicroPython filesystem region (not MakeCode).
    public let isMicroPython: Bool
    public private(set) var currentSegmentAddress: UInt16
    public let codeStartAddress: UInt32
    private var nextData: [(address: UInt16, data: Data)] = []
    private var reader: StreamReader?
    private var skippedCount: Int = 0
    /// For MicroPython: stop iteration when absolute address reaches this value.
    private let endAddress: UInt32?

    init(nextLines: [String], currentSegmentAddress: UInt16, codeStartAddress: UInt32, reader: StreamReader, lineCount: Int, isMicroPython: Bool = false, endAddress: UInt32? = nil) {
        self.reader = reader
        self.nextData = []
        self.currentSegmentAddress = currentSegmentAddress
        self.codeStartAddress = codeStartAddress
        self.lineCount = lineCount
        self.isMicroPython = isMicroPython
        self.endAddress = endAddress
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
        case 0, 0x0D: // Data record (0x0D = micro:bit universal hex Block Start, also raw flash data)
            if record.contains("00000001FF") {
                break
            } else if let data = PartialFlashHexReader.readData(record) {
                // For MicroPython: stop when we reach the end of the filesystem region
                if let end = endAddress {
                    let absAddr = (UInt32(currentSegmentAddress) << 16) | UInt32(data.address)
                    if absAddr >= end {
                        reader?.close()
                        reader = nil
                        return
                    }
                }
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
    static let MICROPYTHON_MAGIC1 = "FE307F59"
    static let MICROPYTHON_MAGIC2 = "9DD7B1C1"

    /// Returns true if the record's data payload contains the MicroPython region table header:
    /// FE307F59 + 16 hex chars (version/table_len/num_reg/pageLog2) + 9DD7B1C1
    static func isMicroPythonStart(_ record: String) -> Bool {
        return !record.matches(regex: ".*FE307F59[0-9A-Fa-f]{16}9DD7B1C1.*").isEmpty
    }

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

// MARK: - CRC32

/// Standard CRC32 implementation (polynomial 0xEDB88320), matching Java's java.util.zip.CRC32.
struct CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var crc = UInt32(i)
        for _ in 0..<8 {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
        }
        return crc
    }

    static func checksum(bytes: [UInt8]) -> UInt32 {
        bytes.reduce(0xFFFFFFFF as UInt32) { crc, byte in
            (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)]
        } ^ 0xFFFFFFFF
    }
}

//MARK: constants for partial flashing
extension UInt8 {
    //commands
    internal static let REBOOT = UInt8(0xFF)
    internal static let STATUS = UInt8(0xEE)
    internal static let REGION = UInt8(0)
    internal static let WRITE = UInt8(1)
    internal static let TRANSMISSION_END = UInt8(2)

    //REGION parameters
    internal static let EMBEDDED_REGION = UInt8(0)
    internal static let DAL_REGION = UInt8(1)
    internal static let PROGRAM_REGION = UInt8(2)

    //STATUS and REBOOT parameters
    internal static let MODE_APPLICATION = UInt8(1)
    internal static let MODE_BLE = UInt8(0)

    //WRITE response values
    internal static let WRITE_FAIL = UInt8(0xAA)
    internal static let WRITE_SUCCESS = UInt8(0xFF)
}
