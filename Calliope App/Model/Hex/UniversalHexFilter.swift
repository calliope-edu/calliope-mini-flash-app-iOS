import Foundation

/// Filters universal hex files to extract only the application region code
/// This reduces partial flash packet count from ~2,300 to ~160 packets
/// Based on micro:bit Android implementation (irmHexUtils.java)
struct UniversalHexFilter {
    
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
        
        while let line = reader.nextLine() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse hex record
            guard let record = parseHexRecord(trimmed) else {
                continue
            }
            
            // Update segment address for type 04 (Extended Linear Address)
            if record.type == 0x04 {
                currentSegmentAddress = UInt32(record.data[0]) << 24 | UInt32(record.data[1]) << 16
                // Include segment address record in output
                filteredLines.append(trimmed)
                continue
            }
            
            // Handle data records (type 00)
            if record.type == 0x00 {
                let fullAddress = currentSegmentAddress + UInt32(record.address)
                
                // Check if this record falls within application region
                if fullAddress + UInt32(record.data.count) > range.min && fullAddress < range.max {
                    // Calculate which bytes to include
                    let first = fullAddress < range.min ? range.min - fullAddress : 0
                    let next = fullAddress + UInt32(record.data.count) > range.max ? range.max - fullAddress : UInt32(record.data.count)
                    
                    if next > first {
                        // This record (or part of it) is in range
                        if first == 0 && next == UInt32(record.data.count) {
                            // Entire record is in range - include as-is
                            filteredLines.append(trimmed)
                        } else {
                            // Partial record - need to reconstruct
                            let newAddress = UInt16(record.address) + UInt16(first)
                            let newData = record.data[Int(first)..<Int(next)]
                            if let newLine = constructHexRecord(address: newAddress, type: 0x00, data: Data(newData)) {
                                filteredLines.append(newLine)
                            }
                        }
                        
                        // Track range
                        let dataStart = fullAddress + first
                        let dataEnd = fullAddress + next
                        resultAddrMin = min(resultAddrMin, dataStart)
                        resultAddrMax = max(resultAddrMax, dataEnd)
                    }
                }
            }
            
            // Include EOF record (type 01)
            if record.type == 0x01 {
                filteredLines.append(trimmed)
                break
            }
        }
        
        LogNotify.log("UniversalHexFilter: Filtered from universal hex")
        LogNotify.log("  Address range: 0x\(String(resultAddrMin, radix: 16)) - 0x\(String(resultAddrMax, radix: 16))")
        LogNotify.log("  Output lines: \(filteredLines.count)")
        
        return filteredLines.isEmpty ? nil : filteredLines
    }
    
    /// Writes filtered hex lines to a temporary file
    /// - Parameter lines: Array of hex record strings
    /// - Returns: URL to the temporary file, or nil on error
    static func writeFilteredHex(_ lines: [String]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("application_filtered.hex")
        
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
    
    /// Construct an Intel HEX record line from components
    private static func constructHexRecord(address: UInt16, type: UInt8, data: Data) -> String? {
        let byteCount = UInt8(data.count)
        
        // Calculate checksum
        var checksum: UInt16 = UInt16(byteCount)
        checksum += UInt16(address >> 8)
        checksum += UInt16(address & 0xFF)
        checksum += UInt16(type)
        for byte in data {
            checksum += UInt16(byte)
        }
        checksum = (0x100 - (checksum & 0xFF)) & 0xFF
        
        // Build hex string
        var hexString = ":"
        hexString += String(format: "%02X", byteCount)
        hexString += String(format: "%04X", address)
        hexString += String(format: "%02X", type)
        for byte in data {
            hexString += String(format: "%02X", byte)
        }
        hexString += String(format: "%02X", checksum)
        
        return hexString
    }
}
