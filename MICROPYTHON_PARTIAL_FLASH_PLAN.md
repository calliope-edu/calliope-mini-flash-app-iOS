# MicroPython Partial Flashing Implementation Plan

## Executive Summary

This document outlines the implementation plan to add MicroPython partial flashing support to the Calliope mini iOS app. Currently, the app only supports partial flashing for MakeCode projects. This enhancement will extend that capability to MicroPython projects, providing faster flashing times for Python users.

## Background Analysis

### Current MakeCode Implementation (iOS)

The existing implementation in `PartialFlashing.swift`:
1. Searches for MakeCode magic marker: `708E3B92C615A841C49866C975EE5197`
2. Reads the next line to extract two 8-byte hashes (DAL hash + program hash)
3. Creates `PartialFlashData` iterator to stream the code section
4. Validates hashes match with device before proceeding with partial flash

### Android MicroPython Implementation Analysis

From `PartialFlashingBaseService.java`, MicroPython hex files have:

1. **Two Magic Markers**: 
   - `UPY_MAGIC1 = "FE307F59"` (start marker)
   - `UPY_MAGIC2 = "9DD7B1C1"` (end marker)
   - Combined regex pattern: `.*FE307F59.{16}9DD7B1C1.*`

2. **Region Table Structure**:
   ```
   ┌─────────────────────────────────────┐
   │  Header (16 bytes)                  │
   │  - Magic markers (8 bytes)          │
   │  - Version (2 bytes, must be 1)     │
   │  - Flags (2 bytes)                  │
   │  - Table length (2 bytes)           │
   │  - Number of regions (2 bytes)      │
   │  - Page size log2 (2 bytes)         │
   ├─────────────────────────────────────┤
   │  Region 0 (16 bytes)                │
   │  Region 1 (16 bytes)                │
   │  ...                                │
   │  Region N (16 bytes)                │
   └─────────────────────────────────────┘
   ```

3. **Each Region Entry (16 bytes)**:
   - Byte 0: Region ID (1=softdevice, 2=micropython app, 3=file system)
   - Byte 1: Reserved
   - Byte 2: Hash type (0=empty, 1=verbatim 8-byte hash, 2=CRC32 pointer)
   - Byte 3: Reserved
   - Bytes 4-5: Start page (uint16, little-endian)
   - Bytes 6-7: Reserved
   - Bytes 8-11: Length in bytes (uint32, little-endian)
   - Bytes 12-15: Hash pointer (uint32, little-endian) OR 4 bytes of hash data
   - Bytes 16-23: Additional 4 bytes of hash data (for hashType=1)

4. **Hash Types**:
   - **Type 0**: No hash data (empty)
   - **Type 1**: 8 bytes of verbatim hash data (stored in bytes 16-23 of region entry)
   - **Type 2**: Hash pointer - points to null-terminated string (max 100 chars), hash is CRC32 of that string

5. **Key Regions**:
   - **Region 2 (micropython app)**: Contains the DAL/runtime hash (fileHash/dalHash)
   - **Region 3 (file system)**: Contains the actual user code to flash (codeStart, codeLength)

### Differences from MakeCode

| Aspect | MakeCode | MicroPython |
|--------|----------|-------------|
| Magic detection | Single 32-char hex string | Two markers with 16 chars between |
| Hash location | Immediately after magic | In region table, region ID=2 |
| Code location | Immediately after hashes | In region table, region ID=3 |
| Hash format | Two 8-byte hashes inline | Region table with hash types |
| Structure | Linear: magic → hashes → code | Structured: header → regions → code |
| Validation | Version check implicit | Explicit version/page size validation |

## Implementation Plan

### Phase 1: Add Helper Methods for MicroPython Detection

**File**: `PartialFlashing.swift`

#### 1.1 Add MicroPython Constants

Add to `PartialFlashHexReader` struct:
```swift
static let MICROPYTHON_MAGIC1 = "FE307F59"
static let MICROPYTHON_MAGIC2 = "9DD7B1C1"
static let MICROPYTHON_MAGIC_PATTERN = ".*FE307F59.{16}9DD7B1C1.*"
static let PYTHON_HEADER_SIZE = 16
static let PYTHON_REGION_SIZE = 16
```

#### 1.2 Add MicroPython Magic Detection

Add method to `PartialFlashHexReader`:
```swift
static func isMicroPythonStart(_ record: String) -> Bool {
    // Check if line matches the MicroPython magic pattern
    // Must contain FE307F59, followed by exactly 16 chars, then 9DD7B1C1
    guard record.count >= 41 else { return false }
    let data = String(record.dropFirst(9)) // Skip :LLAAAATT
    return data.matches(regex: MICROPYTHON_MAGIC_PATTERN).count > 0
}
```

### Phase 2: Implement MicroPython Region Table Parsing

#### 2.1 Add Region Structure

Add new struct in `PartialFlashing.swift`:
```swift
// MARK: - MicroPython Region Table

struct MicroPythonRegion {
    let regionID: UInt8          // 1=softdevice, 2=app, 3=filesystem
    let hashType: UInt8          // 0=empty, 1=verbatim, 2=CRC32 pointer
    let startPage: UInt16        // Starting page number
    let length: UInt32           // Length in bytes
    let hashPointer: UInt32      // Pointer to hash string (for hashType=2)
    let hashData: String         // 8 bytes of hash data as hex string
    
    init?(hexData: String) {
        guard hexData.count >= PYTHON_REGION_SIZE * 2 else { return nil }
        
        // Parse region entry (all values are little-endian)
        self.regionID = UInt8(hexData[0..<2], radix: 16) ?? 0
        self.hashType = UInt8(hexData[4..<6], radix: 16) ?? 0
        
        // Parse start page (little-endian uint16)
        let startPageHex = hexData[8..<12]
        let startPageData = startPageHex.toData(using: .hex)
        self.startPage = UInt16(littleEndianData: startPageData ?? Data()) ?? 0
        
        // Parse length (little-endian uint32)
        let lengthHex = hexData[16..<24]
        let lengthData = lengthHex.toData(using: .hex)
        self.length = UInt32(littleEndianData: lengthData ?? Data()) ?? 0
        
        // Parse hash pointer (little-endian uint32)
        let hashPtrHex = hexData[24..<32]
        let hashPtrData = hashPtrHex.toData(using: .hex)
        self.hashPointer = UInt32(littleEndianData: hashPtrData ?? Data()) ?? 0
        
        // Extract hash data (last 8 bytes of region entry)
        self.hashData = hexData[32..<48]
    }
}
```

#### 2.2 Add Region Table Parser

Add method to `PartialFlashManager`:
```swift
/// Parse MicroPython region table from hex file
/// - Parameter url: URL of the MicroPython hex file
/// - Returns: Array of regions or nil if invalid
private static func parseMicroPythonRegionTable(from url: URL, magicLine: String, 
                                                segmentAddress: UInt16) -> [MicroPythonRegion]? {
    guard let reader = StreamReader(path: url.path) else {
        return nil
    }
    defer { reader.close() }
    
    // Find the magic marker line
    var currentSegment = segmentAddress
    var foundMagic = false
    while let line = reader.nextLine() {
        // Track segment address changes
        if PartialFlashHexReader.type(of: line) == 4,
           let length = PartialFlashHexReader.length(of: line), length == 2,
           let data = PartialFlashHexReader.data(of: line, length) {
            currentSegment = (UInt16(data[0]) << 8) | UInt16(data[1])
        }
        
        if line == magicLine {
            foundMagic = true
            break
        }
    }
    
    guard foundMagic else { return nil }
    
    // Read header from the magic line
    guard let headerData = extractDataAcrossLines(reader: reader, startOffset: 0, 
                                                   byteCount: PYTHON_HEADER_SIZE) else {
        return nil
    }
    
    // Parse header
    let version = UInt16(littleEndianData: headerData[4..<6]) ?? 0
    let tableLength = UInt16(littleEndianData: headerData[6..<8]) ?? 0
    let numRegions = UInt16(littleEndianData: headerData[8..<10]) ?? 0
    let pageLog2 = UInt16(littleEndianData: headerData[10..<12]) ?? 0
    
    // Validate header
    guard version == 1 else {
        LogNotify.log("[PartialFlash] MicroPython: Invalid version \(version), expected 1")
        return nil
    }
    
    guard tableLength == numRegions * PYTHON_REGION_SIZE else {
        LogNotify.log("[PartialFlash] MicroPython: Table length mismatch")
        return nil
    }
    
    // Validate page size (V1=0x400=1024 bytes, V2=0x1000=4096 bytes)
    let expectedPageSize: UInt32 = 0x1000 // V2/Calliope mini uses 4KB pages
    let actualPageSize = UInt32(1) << pageLog2
    guard actualPageSize == expectedPageSize else {
        LogNotify.log("[PartialFlash] MicroPython: Page size mismatch \(actualPageSize) != \(expectedPageSize)")
        return nil
    }
    
    // Parse regions (they are stored BEFORE the header in the hex file)
    var regions: [MicroPythonRegion] = []
    // Calculate address of first region (header address - table length)
    // Need to re-scan to find regions...
    
    // For simplicity, read all regions from current position
    for _ in 0..<numRegions {
        guard let regionData = extractDataAcrossLines(reader: reader, startOffset: 0,
                                                       byteCount: PYTHON_REGION_SIZE) else {
            return nil
        }
        
        if let region = MicroPythonRegion(hexData: regionData.hexEncodedString()) {
            regions.append(region)
        }
    }
    
    return regions
}
```

#### 2.3 Add Hash Extraction from Region

Add method to `PartialFlashManager`:
```swift
/// Extract hash from MicroPython region based on hash type
/// - Parameters:
///   - region: The region containing hash information
///   - url: URL of hex file (needed for hashType=2)
/// - Returns: 8-byte hash as hex string or nil
private static func extractHashFromRegion(_ region: MicroPythonRegion, 
                                          url: URL) -> String? {
    switch region.hashType {
    case 0:
        // Empty hash
        return nil
        
    case 1:
        // Verbatim 8-byte hash stored in region.hashData
        return region.hashData
        
    case 2:
        // Hash is CRC32 of null-terminated string at hashPointer
        return extractCRC32Hash(fromAddress: region.hashPointer, url: url)
        
    default:
        LogNotify.log("[PartialFlash] MicroPython: Unknown hash type \(region.hashType)")
        return nil
    }
}

/// Extract CRC32 hash from pointer address
private static func extractCRC32Hash(fromAddress address: UInt32, url: URL) -> String? {
    guard let reader = StreamReader(path: url.path) else { return nil }
    defer { reader.close() }
    
    // Search for the address in hex file
    var currentSegment: UInt32 = 0
    var foundAddress = false
    
    while let line = reader.nextLine() {
        // Track ELA changes
        if PartialFlashHexReader.type(of: line) == 4,
           let length = PartialFlashHexReader.length(of: line), length == 2,
           let data = PartialFlashHexReader.data(of: line, length) {
            currentSegment = (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16)
        }
        
        // Check data records
        if PartialFlashHexReader.type(of: line) == 0,
           let recordAddr = PartialFlashHexReader.address(of: line) {
            let fullAddr = currentSegment | UInt32(recordAddr)
            
            if fullAddr <= address && fullAddr + UInt32(line.count / 2) > address {
                // Found the line containing the address
                foundAddress = true
                
                // Extract string starting at this address
                let offset = Int(address - fullAddr)
                guard let data = PartialFlashHexReader.data(of: line, 
                                    PartialFlashHexReader.length(of: line) ?? 0) else {
                    return nil
                }
                
                // Read null-terminated string (max 100 bytes)
                var stringBytes: [UInt8] = []
                for i in offset..<min(offset + 100, data.count) {
                    let byte = data[i]
                    if byte == 0 { break }
                    stringBytes.append(byte)
                }
                
                // Calculate CRC32
                let crc32 = CRC32.checksum(bytes: stringBytes)
                
                // Convert to 8-byte hex string (little-endian uint64)
                var value = UInt64(crc32)
                let data = Data(bytes: &value, count: 8)
                return data.hexEncodedString()
            }
        }
    }
    
    return nil
}
```

#### 2.4 Add CRC32 Implementation

Since Swift doesn't have built-in CRC32, add to `PartialFlashing.swift`:
```swift
// MARK: - CRC32 Helper

struct CRC32 {
    private static let table: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc = crc >> 1
                }
            }
            table[i] = crc
        }
        return table
    }()
    
    static func checksum(bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in bytes {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        return ~crc
    }
}
```

### Phase 3: Integrate MicroPython Detection into Main Flow

#### 3.1 Modify `forwardToMagicNumber` to detect both types

Update the method in `PartialFlashManager`:
```swift
/// Forward reader to magic marker (MakeCode or MicroPython), tracking ELA segments
/// - Parameter reader: StreamReader positioned at start of hex file
/// - Returns: Tuple of (magic line or nil, current segment address, code start address, isMicroPython)
private static func forwardToMagicNumber(_ reader: StreamReader) 
    -> (String?, UInt16, UInt32, Bool) {
    var magicLine: String?
    var currentSegmentAddress: UInt16 = 0
    var codeStartAddress: UInt32 = 0
    var isMicroPython = false
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
        
        // Check for MicroPython magic first
        if PartialFlashHexReader.isMicroPythonStart(record) {
            let recordAddress = PartialFlashHexReader.address(of: record) ?? 0
            let absoluteAddress = UInt32(currentSegmentAddress) << 16 | UInt32(recordAddress)
            
            LogNotify.log("[PartialFlash] Found MicroPython magic at 0x\(String(absoluteAddress, radix: 16))")
            magicLine = record
            codeStartAddress = absoluteAddress
            isMicroPython = true
            break
        }
        
        // Check for MakeCode magic pattern
        if PartialFlashHexReader.isMagicStart(record) {
            let recordAddress = PartialFlashHexReader.address(of: record) ?? 0
            let absoluteAddress = UInt32(currentSegmentAddress) << 16 | UInt32(recordAddress)
            
            LogNotify.log("[PartialFlash] Found MakeCode magic at 0x\(String(absoluteAddress, radix: 16))")
            magicLine = record
            codeStartAddress = absoluteAddress
            isMicroPython = false
            break
        }
    }
    
    return (magicLine, currentSegmentAddress, codeStartAddress, isMicroPython)
}
```

#### 3.2 Update `retrievePartialFlashingInfo` to handle both types

Modify the main entry point:
```swift
static func retrievePartialFlashingInfo(from url: URL) 
    -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
    
    LogNotify.log("[PartialFlash] Starting retrievePartialFlashingInfo for: \(url.lastPathComponent)")
    
    guard isPartialFlashingEnabled else {
        LogNotify.log("[PartialFlash] ❌ Partial flashing disabled in settings")
        return nil
    }
    
    guard let reader = StreamReader(path: url.path) else { return nil }
    
    let (magicLine, segmentAddr, codeStart, isMicroPython) = forwardToMagicNumber(reader)
    reader.close()
    
    guard magicLine != nil else {
        LogNotify.log("[PartialFlash] ❌ No magic marker found")
        return nil
    }
    
    if isMicroPython {
        return retrieveMicroPythonPartialFlashingInfo(from: url, magicLine: magicLine!,
                                                       segmentAddress: segmentAddr)
    } else {
        return retrieveMakeCodePartialFlashingInfo(from: url)
    }
}
```

#### 3.3 Add MicroPython-specific retrieval method

```swift
/// Retrieve partial flashing info for MicroPython hex files
private static func retrieveMicroPythonPartialFlashingInfo(from url: URL, 
                                                            magicLine: String,
                                                            segmentAddress: UInt16)
    -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
    
    LogNotify.log("[PartialFlash] Processing MicroPython hex file")
    
    // Parse region table
    guard let regions = parseMicroPythonRegionTable(from: url, magicLine: magicLine,
                                                     segmentAddress: segmentAddress) else {
        LogNotify.log("[PartialFlash] ❌ Failed to parse MicroPython region table")
        return nil
    }
    
    // Find micropython app region (ID=2) for DAL hash
    guard let appRegion = regions.first(where: { $0.regionID == 2 }) else {
        LogNotify.log("[PartialFlash] ❌ No MicroPython app region found")
        return nil
    }
    
    guard let dalHashHex = extractHashFromRegion(appRegion, url: url) else {
        LogNotify.log("[PartialFlash] ❌ Failed to extract DAL hash")
        return nil
    }
    
    // Find file system region (ID=3) for user code
    guard let fsRegion = regions.first(where: { $0.regionID == 3 }) else {
        LogNotify.log("[PartialFlash] ❌ No file system region found")
        return nil
    }
    
    // Calculate page size (V2/Calliope = 0x1000 = 4096 bytes)
    let pageSize: UInt32 = 0x1000
    let codeStartAddress = UInt32(fsRegion.startPage) * pageSize
    let codeLength = fsRegion.length
    
    LogNotify.log("[PartialFlash] MicroPython code: start=0x\(String(codeStartAddress, radix: 16)) length=\(codeLength)")
    
    // Convert DAL hash to Data
    guard let dalHashData = dalHashHex.toData(using: .hex) else {
        LogNotify.log("[PartialFlash] ❌ Invalid DAL hash format")
        return nil
    }
    
    // For MicroPython, use same hash for both fileHash and programHash
    // (The program hash concept doesn't apply the same way)
    
    // Create PartialFlashData from file system region
    guard let partialData = createMicroPythonPartialFlashData(from: url,
                                                               startAddress: codeStartAddress,
                                                               length: codeLength) else {
        LogNotify.log("[PartialFlash] ❌ Failed to create PartialFlashData")
        return nil
    }
    
    // Check if packet count is reasonable
    if partialData.lineCount > 2000 {
        LogNotify.log("[PartialFlash] ❌ Too many packets (\(partialData.lineCount) > 2000)")
        return nil
    }
    
    LogNotify.log("[PartialFlash] ✅ MicroPython partial flashing approved")
    return (dalHashData, dalHashData, partialData)
}
```

#### 3.4 Rename existing method for clarity

Rename `extractHashes` and `createPartialFlashData` to be MakeCode-specific:
```swift
// Keep existing implementations but rename for clarity
static func extractMakeCodeHashes(from url: URL) -> (fileHash: Data, programHash: Data)? {
    // Current extractHashes implementation
}

static func createMakeCodePartialFlashData(from url: URL) -> PartialFlashData? {
    // Current createPartialFlashData implementation
}

private static func retrieveMakeCodePartialFlashingInfo(from url: URL)
    -> (fileHash: Data, programHash: Data, partialFlashData: PartialFlashData)? {
    // Move current implementation from retrievePartialFlashingInfo here
}
```

### Phase 4: Implement MicroPython Data Iterator

Add method to create `PartialFlashData` for MicroPython:

```swift
/// Create PartialFlashData from MicroPython file system region
private static func createMicroPythonPartialFlashData(from url: URL,
                                                       startAddress: UInt32,
                                                       length: UInt32) 
    -> PartialFlashData? {
    
    LogNotify.log("[PartialFlash] Creating MicroPython PartialFlashData")
    
    guard let reader = StreamReader(path: url.path) else { return nil }
    
    // Find the start address in hex file
    var currentSegment: UInt32 = 0
    var foundStart = false
    var initialLines: [String] = []
    
    while let line = reader.nextLine() {
        // Track ELA changes
        if PartialFlashHexReader.type(of: line) == 4,
           let length = PartialFlashHexReader.length(of: line), length == 2,
           let data = PartialFlashHexReader.data(of: line, length) {
            currentSegment = (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16)
        }
        
        // Check if this line contains our start address
        if PartialFlashHexReader.type(of: line) == 0,
           let recordAddr = PartialFlashHexReader.address(of: line) {
            let fullAddr = currentSegment | UInt32(recordAddr)
            
            if fullAddr >= startAddress && fullAddr < startAddress + length {
                foundStart = true
                initialLines.append(line)
                break
            }
        }
    }
    
    guard foundStart else {
        LogNotify.log("[PartialFlash] ❌ Could not find start address in hex")
        return nil
    }
    
    // Count non-empty lines in the region
    var numLinesToFlash = 0
    var totalLines = 0
    var bytesRead: UInt32 = 0
    
    while let line = reader.nextLine(), bytesRead < length {
        if PartialFlashHexReader.type(of: line) == 0 {
            totalLines += 1
            if let data = PartialFlashHexReader.readData(line), 
               !data.data.allSatisfy({ $0 == 0xFF }) {
                numLinesToFlash += 1
            }
            bytesRead += UInt32(data?.data.count ?? 0)
        }
    }
    
    LogNotify.log("[PartialFlash] MicroPython: \(numLinesToFlash) non-empty lines")
    
    // Create fresh reader for iteration
    guard let freshReader = StreamReader(path: url.path) else { return nil }
    
    // Re-find the start position
    // ... (similar logic as above to position reader)
    
    return PartialFlashData(
        nextLines: initialLines,
        currentSegmentAddress: UInt16(currentSegment >> 16),
        codeStartAddress: startAddress,
        reader: freshReader,
        lineCount: numLinesToFlash
    )
}
```

### Phase 5: Testing Strategy

#### 5.1 Test Cases

1. **MakeCode Regression Test**
   - Verify existing MakeCode partial flashing still works
   - Test all three magic marker locations (0x47000, 0x77000, 0x1F000)

2. **MicroPython Detection**
   - Test MicroPython hex file is correctly identified
   - Test MicroPython magic pattern detection
   - Test non-partial-flashable MicroPython files fall back to DFU

3. **Region Table Parsing**
   - Test header validation (version, page size, table length)
   - Test region parsing with different hash types (0, 1, 2)
   - Test extraction of app region (ID=2) and file system region (ID=3)

4. **Hash Extraction**
   - Test verbatim hash extraction (hashType=1)
   - Test CRC32 hash extraction (hashType=2)
   - Test hash comparison with device

5. **Data Transmission**
   - Test MicroPython code region data iterator
   - Test packet count is reasonable (<2000)
   - Test actual flashing succeeds

6. **Edge Cases**
   - Test hex file with no magic marker → DFU fallback
   - Test malformed region table → DFU fallback
   - Test hash mismatch → DFU fallback
   - Test mixed MakeCode/MicroPython (should not happen, but handle gracefully)

#### 5.2 Test Files Needed

- Sample MicroPython hex file from micro:bit Python editor
- Sample MicroPython hex file with hashType=1
- Sample MicroPython hex file with hashType=2
- Existing MakeCode test files (for regression)

### Phase 6: Documentation Updates

Update the following files:

1. **PARTIAL_FLASH_DOCUMENTATION.md**
   - Add MicroPython section
   - Document region table structure
   - Update decision tree to include MicroPython

2. **README.md**
   - Mention MicroPython partial flashing support

3. **Code Comments**
   - Add detailed comments explaining MicroPython region table format
   - Document hash types and their handling

## Implementation Checklist

- [ ] Phase 1: Add MicroPython constants and detection methods
- [ ] Phase 2: Implement region table parsing
- [ ] Phase 3: Integrate MicroPython flow into main method
- [ ] Phase 4: Implement MicroPython data iterator
- [ ] Phase 5: Write unit tests
- [ ] Phase 6: Integration testing with real device
- [ ] Phase 7: Update documentation
- [ ] Phase 8: Code review and refinement

## Estimated Effort

- **Phase 1-2**: 4-6 hours (core parsing logic)
- **Phase 3-4**: 4-6 hours (integration)
- **Phase 5**: 6-8 hours (testing)
- **Phase 6**: 1-2 hours (documentation)
- **Total**: ~15-22 hours

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| CRC32 implementation bugs | High | Use test vectors from Android implementation |
| Region table parsing errors | High | Extensive logging and validation |
| Little-endian conversion issues | Medium | Test with known good hex files |
| Breaking MakeCode support | High | Comprehensive regression tests |
| Performance issues | Low | Profile and optimize if needed |

## Success Criteria

1. ✅ MicroPython hex files are correctly detected
2. ✅ Region table is parsed correctly
3. ✅ DAL hash is extracted correctly for all hash types
4. ✅ File system code region is located correctly
5. ✅ Partial flashing succeeds for MicroPython programs
6. ✅ MakeCode partial flashing continues to work (regression test)
7. ✅ Non-partial-flashable files fall back to DFU gracefully
8. ✅ All tests pass
9. ✅ Documentation is updated

## References

1. Android implementation: `PartialFlashingBaseService.java`
2. MicroPython region table spec: [micropython-microbit-v2 addlayouttable.py](https://github.com/microbit-foundation/micropython-microbit-v2/blob/a76e1413bcd66f128a31d98756fc3d1f336d1580/src/addlayouttable.py)
3. Current iOS implementation: `PartialFlashing.swift`
4. Intel HEX format: [Wikipedia](https://en.wikipedia.org/wiki/Intel_HEX)
