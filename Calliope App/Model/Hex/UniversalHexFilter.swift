import Foundation

/// Filters universal hex files to extract only the application region code
/// This reduces partial flash packet count from ~2,300 to ~160 packets
/// Based on micro:bit Android implementation (irmHexUtils.java)
struct UniversalHexFilter {
    
    // Intel HEX record types
    private enum RecordType: UInt8 {
        case data = 0x00                    // Data record
        case endOfFile = 0x01               // End of file
        case extendedLinearAddress = 0x04   // Extended linear address (upper 16 bits)
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
    /// - Parameters:
    ///   - sourceURL: Path to the universal hex file
    ///   - hexBlock: Target hardware version (v1 or v2)
    /// - Returns: Array of filtered hex lines (as Strings) or nil on error
    static func filterUniversalHex(sourceURL: URL, hexBlock: HexBlock) -> [String]? {
        guard let reader = StreamReader(path: sourceURL.path) else {
            LogNotify.log("UniversalHexFilter: Failed to open file")
            return nil
        }
        defer { reader.close() }
        
        let range = hexBlock.addressRange
        var filteredLines: [String] = []
        var currentSegmentAddress: UInt32 = 0
        
        // Track the actual data range we're extracting
        var resultAddrMin: UInt32 = UInt32.max
        var resultAddrMax: UInt32 = 0
        
        LogNotify.log("UniversalHexFilter: Filtering address range 0x\(String(range.min, radix: 16)) - 0x\(String(range.max, radix: 16))")
        
        while let line = reader.nextLine() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse hex record
            guard let record = parseHexRecord(trimmed) else {
                continue
            }
            
            // Update segment address for type 04 (Extended Linear Address)
            if record.type == RecordType.extendedLinearAddress.rawValue {
                currentSegmentAddress = UInt32(record.data[0]) << 24 | UInt32(record.data[1]) << 16
                // Always include segment address records for proper hex format
                filteredLines.append(trimmed)
                continue
            }
            
            // Handle data records (type 00) - filter by address range
            if record.type == RecordType.data.rawValue {
                let fullAddress = currentSegmentAddress + UInt32(record.address)
                
                // Check if this record overlaps with application region
                if fullAddress < range.max && fullAddress + UInt32(record.data.count) > range.min {
                    filteredLines.append(trimmed)
                    resultAddrMin = min(resultAddrMin, fullAddress)
                    resultAddrMax = max(resultAddrMax, fullAddress + UInt32(record.data.count))
                }
            }
            
            // Include EOF record (type 01)
            if record.type == RecordType.endOfFile.rawValue {
                filteredLines.append(trimmed)
                break
            }
        }
        
        LogNotify.log("UniversalHexFilter: Filtered from universal hex")
        LogNotify.log("  Data range: 0x\(String(resultAddrMin, radix: 16)) - 0x\(String(resultAddrMax, radix: 16))")
        LogNotify.log("  Output lines: \(filteredLines.count)")
        
        return filteredLines.isEmpty ? nil : filteredLines
    }
    
    /// Writes filtered hex lines to a temporary file
    /// - Parameter lines: Array of hex record strings
    /// - Returns: URL to the temporary file, or nil on error
    static func writeFilteredHex(_ lines: [String]) -> URL? {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("application_filtered.hex")
        
        let content = lines.joined(separator: "\n")
        
        do {
            try content.write(to: tempFile, atomically: true, encoding: .utf8)
            LogNotify.log("UniversalHexFilter: Wrote filtered hex to \(tempFile.path)")
            return tempFile
        } catch {
            LogNotify.log("UniversalHexFilter: Failed to write file: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Functions
    
    private struct HexRecord {
        let address: UInt16
        let type: UInt8
        let data: Data
    }
    
    /// Parse an Intel HEX record line
    private static func parseHexRecord(_ line: String) -> HexRecord? {
        // Format: :LLAAAATT[DD...]CC
        // LL = byte count, AAAA = address, TT = type, DD = data, CC = checksum
        
        guard line.hasPrefix(":"), line.count >= 11 else {
            return nil
        }
        
        let hex = String(line.dropFirst()) // Remove ':'
        
        guard let byteCount = UInt8(hex.prefix(2), radix: 16),
              let address = UInt16(hex.dropFirst(2).prefix(4), radix: 16),
              let type = UInt8(hex.dropFirst(6).prefix(2), radix: 16) else {
            return nil
        }
        
        // Extract data bytes
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
    
}
