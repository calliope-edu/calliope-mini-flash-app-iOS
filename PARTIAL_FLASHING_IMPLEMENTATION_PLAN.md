# Partial Flashing Implementation Plan for Calliope iOS App

## Executive Summary

Enable reliable partial flashing for Calliope V3 by fixing the existing implementation to respect iOS CoreBluetooth flow control and device protocol constraints. This plan follows the proven micro:bit Android implementation pattern and stays within Nordic DFU library design boundaries.

---

## Current Status

✅ **COMPLETED:**
- Partial flashing enabled in CalliopeV3 optionalServices
- Override that forced full DFU removed
- Characteristic notifications enabled for partial flashing service

❌ **ISSUES TO FIX:**
1. No iOS CoreBluetooth flow control (buffer overflow risk)
2. Missing timeout handling and retry logic
3. No proper progress tracking during transmission
4. Potential race conditions in notification handling

---

## Implementation Strategy

### Core Principle
**Follow the micro:bit Android proven pattern**: Send 4 packets → Wait for device ACK → Send next 4 packets

**DO NOT attempt pipelining** - the "optimized" approach violates iOS BLE buffer limits and device protocol.

---

## Phase 1: Add iOS CoreBluetooth Flow Control (HIGH PRIORITY)

### Problem
Current implementation in `FlashableBLECalliope.sendCurrentPackages()`:
```swift
for (index, package) in currentDataToFlash.enumerated() {
    let writeData = packageAddress + packageNumber + package.data
    send(command: .WRITE, value: writeData)  // ← No flow control!
}
```

Calls `writeWithoutResponse()` 4 times rapidly without checking if the BLE buffer can accept data.

### Solution: Implement Nordic DFU Pattern

Following `iOSDFULibrary/DFUPacket.swift` pattern:

```swift
// In FlashableBLECalliope.swift

private func sendCurrentPackages() {
    updateCallback("Sending \(currentDataToFlash.count) packages, beginning at \(startPackageNumber)")
    
    for (index, package) in currentDataToFlash.enumerated() {
        // CRITICAL: Check if peripheral is ready before each write (iOS 11+)
        if #available(iOS 11.0, *) {
            // Wait until buffer has space (except for first packet)
            while index > 0 && !peripheral.canSendWriteWithoutResponse {
                // Buffer is full, wait 10ms and check again
                Thread.sleep(forTimeInterval: 0.01)
                
                // Safety timeout after 1 second
                // Note: In practice, this should never timeout as device processes packets quickly
            }
        }
        
        let packageAddress = index == 1 ? currentSegmentAddress.bigEndianData : package.address.bigEndianData
        let packageNumber = Data([startPackageNumber + UInt8(index)])
        let writeData = packageAddress + packageNumber + package.data
        send(command: .WRITE, value: writeData)
    }
}
```

### Alternative: Use DispatchQueue Timer (Preferred for iOS)

More iOS-idiomatic approach without blocking Thread.sleep():

```swift
private var packetsToSend: [(index: Int, package: (address: UInt16, data: Data))] = []
private var currentBlockSendIndex = 0

private func sendCurrentPackagesWithFlowControl() {
    packetsToSend = currentDataToFlash.enumerated().map { ($0.offset, $0.element) }
    currentBlockSendIndex = 0
    sendNextPacketInBlock()
}

private func sendNextPacketInBlock() {
    guard currentBlockSendIndex < packetsToSend.count else {
        // All packets in block sent, now wait for device notification
        return
    }
    
    let (index, package) = packetsToSend[currentBlockSendIndex]
    
    // Check buffer availability (iOS 11+)
    if #available(iOS 11.0, *) {
        if index > 0 && !peripheral.canSendWriteWithoutResponse {
            // Buffer full, retry in 10ms
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.sendNextPacketInBlock()
            }
            return
        }
    }
    
    // Send packet
    let packageAddress = index == 1 ? currentSegmentAddress.bigEndianData : package.address.bigEndianData
    let packageNumber = Data([startPackageNumber + UInt8(index)])
    let writeData = packageAddress + packageNumber + package.data
    send(command: .WRITE, value: writeData)
    
    // Move to next packet
    currentBlockSendIndex += 1
    
    // Continue sending immediately (buffer checks will throttle if needed)
    sendNextPacketInBlock()
}
```

---

## Phase 2: Implement Robust Timeout Handling

### Problem
Current implementation has no per-block timeout, only relies on device notifications.

### Solution: Add Block Transmission Timeout

```swift
// In FlashableBLECalliope.swift

private var blockSendStartTime: Date?
private var blockTransmissionTimer: Timer?
private let blockTimeout: TimeInterval = 5.0  // 5 seconds per block

private func sendNextPackages() {
    guard var partialFlashData = partialFlashData else {
        fallbackToFullFlash()
        return
    }
    
    currentSegmentAddress = partialFlashData.currentSegmentAddress
    currentDataToFlash = []
    for _ in 0..<4 {
        guard let nextPackage = partialFlashData.next() else {
            break
        }
        currentDataToFlash.append(nextPackage)
    }
    self.partialFlashData = partialFlashData
    
    // Start timeout timer
    blockSendStartTime = Date()
    blockTransmissionTimer?.invalidate()
    blockTransmissionTimer = Timer.scheduledTimer(withTimeInterval: blockTimeout, repeats: false) { [weak self] _ in
        self?.handleBlockTimeout()
    }
    
    sendCurrentPackagesWithFlowControl()
    
    if currentDataToFlash.count < 4 {
        endTransmission()
    }
    
    startPackageNumber = startPackageNumber.addingReportingOverflow(UInt8(currentDataToFlash.count)).partialValue
    linesFlashed += currentDataToFlash.count
    
    if linesFlashed + 4 > partialFlashData.lineCount {
        statusDelegate?.dfuStateDidChange(to: .completed)
    }
}

private func handleBlockTimeout() {
    LogNotify.log("Block transmission timeout - falling back to full flash")
    fallbackToFullFlash()
}

// In handlePartialValueNotification - cancel timer on success
func handlePartialValueNotification(_ value: Data) {
    // ... existing code ...
    
    if value[0] == .WRITE {
        // Cancel timeout timer
        blockTransmissionTimer?.invalidate()
        blockTransmissionTimer = nil
        
        updateCallback("write status: \(Data([value[1]]).hexEncodedString())")
        if value[1] == .WRITE_FAIL {
            LogNotify.log("Received error message, stopping transmission")
            _ = cancelUpload()
            resendPackages()
        } else if value[1] == .WRITE_SUCCESS {
            sendNextPackages()
        } else {
            fallbackToFullFlash()
        }
        return
    }
}
```

---

## Phase 3: Implement Retry Logic for Failed Blocks

### Problem
Current `resendPackages()` immediately falls back to full flash - no retry attempt.

### Solution: Add Limited Retry Mechanism

```swift
// In FlashableBLECalliope.swift

private var currentBlockRetryCount = 0
private let maxBlockRetries = 3

private func resendPackages() {
    currentBlockRetryCount += 1
    
    if currentBlockRetryCount > maxBlockRetries {
        LogNotify.log("Max retries (\(maxBlockRetries)) exceeded, falling back to full flash")
        fallbackToFullFlash()
        return
    }
    
    LogNotify.log("Retrying block transmission (attempt \(currentBlockRetryCount)/\(maxBlockRetries))")
    
    // Reset packet send index and retry same block
    currentBlockSendIndex = 0
    
    // Add small delay before retry (100ms)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.sendCurrentPackagesWithFlowControl()
    }
}

// Reset retry counter on successful block
func handlePartialValueNotification(_ value: Data) {
    // ... existing code ...
    
    if value[0] == .WRITE {
        blockTransmissionTimer?.invalidate()
        blockTransmissionTimer = nil
        
        if value[1] == .WRITE_SUCCESS {
            currentBlockRetryCount = 0  // ← Reset on success
            sendNextPackages()
        }
        // ...
    }
}
```

---

## Phase 4: Improve Progress Tracking

### Problem
Progress callback only updates based on `linesFlashed`, doesn't account for time or retries.

### Solution: Add Detailed Progress Information

```swift
// In FlashableBLECalliope.swift

private var partialFlashStartTime: Date?
private var totalPacketsToSend: Int = 0
private var totalPacketsSent: Int = 0

func startPartialFlashing() {
    // ... existing code ...
    
    partialFlashStartTime = Date()
    totalPacketsToSend = partialFlashingInfo.partialFlashData.lineCount
    totalPacketsSent = 0
    currentBlockRetryCount = 0
    
    // ... rest of existing code ...
}

private func updateCallback(_ logMessage: String) {
    logReceiver?.logWith(.info, message: logMessage)
    
    let progressPercent = Int(floor(Double(linesFlashed * 100) / Double(partialFlashData?.lineCount ?? Int.max)))
    
    // Calculate speed if we have timing data
    var avgSpeed: Double = 0
    if let startTime = partialFlashStartTime {
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > 0 {
            avgSpeed = Double(totalPacketsSent * 16) / elapsed  // bytes per second
        }
    }
    
    LogNotify.log("Partial flashing progress: \(progressPercent)% (speed: \(Int(avgSpeed)) bytes/s)")
    progressReceiver?.dfuProgressDidChange(
        for: 1, 
        outOf: 1, 
        to: progressPercent, 
        currentSpeedBytesPerSecond: avgSpeed, 
        avgSpeedBytesPerSecond: avgSpeed
    )
}
```

---

## Phase 5: Thread Safety for Notification Handling

### Problem
Notifications arrive on BLE queue, state is accessed from multiple threads.

### Solution: Synchronize State Access

```swift
// In FlashableBLECalliope.swift

private let partialFlashingStateLock = NSLock()
private var isPartialFlashingActive = false

override func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {
    guard characteristic == .partialFlashing else {
        super.handleValueUpdate(characteristic, value)
        return
    }
    
    // Ensure we're on updateQueue and have exclusive access
    updateQueue.async { [weak self] in
        guard let self = self else { return }
        
        self.partialFlashingStateLock.lock()
        defer { self.partialFlashingStateLock.unlock() }
        
        guard self.isPartialFlashingActive else {
            // Ignore notifications if not actively flashing
            return
        }
        
        self.handlePartialValueNotification(value)
    }
}

func startPartialFlashing() {
    // ... existing code ...
    
    partialFlashingStateLock.lock()
    isPartialFlashingActive = true
    partialFlashingStateLock.unlock()
    
    // ... rest of code ...
}

private func endTransmission() {
    partialFlashingStateLock.lock()
    isPartialFlashingActive = false
    isPartiallyFlashing = false
    partialFlashingStateLock.unlock()
    
    shouldRebootOnDisconnect = false
    updateCallback("Partial flashing done!")
    send(command: .TRANSMISSION_END)
}
```

---

## Phase 6: Enhanced Logging for Debugging

### Solution: Add Detailed Debug Logs

```swift
// In FlashableBLECalliope.swift

private func debugLog(_ message: String) {
    #if DEBUG
    let timestamp = Date()
    LogNotify.log("[PF-\(timestamp.timeIntervalSince1970)] \(message)")
    #endif
}

private func sendCurrentPackagesWithFlowControl() {
    debugLog("Starting block send: \(currentDataToFlash.count) packets, block #\(startPackageNumber)")
    
    for (index, package) in currentDataToFlash.enumerated() {
        if #available(iOS 11.0, *) {
            let canSend = peripheral.canSendWriteWithoutResponse
            debugLog("Packet \(index): canSend=\(canSend)")
            
            if index > 0 && !canSend {
                debugLog("Buffer full, waiting...")
            }
        }
        
        // ... send packet ...
        debugLog("Sent packet \(startPackageNumber + UInt8(index)): addr=\(package.address.bigEndian), data=\(package.data.hexEncodedString())")
    }
}

func handlePartialValueNotification(_ value: Data) {
    debugLog("Received notification: \(value.hexEncodedString())")
    
    // ... existing handling ...
}
```

---

## Phase 7: Validation Testing Checklist

### Test Cases to Verify

1. **Flow Control Test**
   - Send large file (>100KB)
   - Verify no buffer overflows
   - Check `canSendWriteWithoutResponse` logs

2. **Timeout Test**
   - Simulate slow device (delay on device side)
   - Verify timeout triggers correctly
   - Verify fallback to full DFU

3. **Retry Test**
   - Force WRITE_FAIL response
   - Verify retry mechanism (up to 3 times)
   - Verify fallback after max retries

4. **Connection Loss Test**
   - Disconnect during transmission
   - Verify proper error handling
   - Verify no crash or hung state

5. **Progress Test**
   - Verify progress updates are smooth
   - Verify speed calculation is accurate
   - Verify UI updates without lag

6. **Thread Safety Test**
   - Send multiple files rapidly
   - Verify no race conditions
   - Verify no memory leaks

---

## Implementation Priority

### Week 1: Core Flow Control
- [ ] Implement `sendCurrentPackagesWithFlowControl()`
- [ ] Add `canSendWriteWithoutResponse` checking
- [ ] Test with iOS 11+ devices

### Week 2: Timeout & Retry
- [ ] Implement block timeout mechanism
- [ ] Add retry logic (max 3 attempts)
- [ ] Test with various file sizes

### Week 3: Polish & Debug
- [ ] Add thread safety locks
- [ ] Enhance logging
- [ ] Fix any edge cases found in testing

### Week 4: Validation
- [ ] Run all test cases
- [ ] Performance benchmarking vs full DFU
- [ ] Beta testing with real users

---

## Success Metrics

- ✅ Partial flashing completes without timeout (>95% success rate)
- ✅ No buffer overflow errors in logs
- ✅ Average flash time: 3-8 seconds (vs 30-60s for full DFU)
- ✅ Retry mechanism handles transient errors gracefully
- ✅ No crashes or hangs during connection loss

---

## References

### Micro:bit Android Implementation
- File: `microbit-android/pfLibrary/src/main/java/org/microbit/android/partialflashing/PartialFlashingBaseService.java`
- Key sections:
  - Lines 869-1073: Main partial flash loop with 4-packet blocks
  - Lines 1000-1038: Packet sending with wait after 4 packets
  - Lines 1671-1707: Memory map reading protocol

### Nordic DFU Library Pattern
- File: `Pods/iOSDFULibrary/Library/Classes/Implementation/LegacyDFU/Characteristics/DFUPacket.swift`
- Key sections:
  - Lines 201-209: `canSendWriteWithoutResponse` checking
  - Lines 185-220: Progress tracking during transmission

### Calliope Protocol Documentation
- Device firmware expects synchronous 4-packet blocks
- WRITE_SUCCESS (0xFF) = proceed with next block
- WRITE_FAIL (0xAA) = retry current block
- TRANSMISSION_END (0x02) = complete session

---

## Risk Mitigation

### Risk: iOS Buffer Overflow
**Mitigation:** Use `canSendWriteWithoutResponse` on iOS 11+, add delays for older iOS

### Risk: Device Firmware Variations
**Mitigation:** Test on multiple Calliope hardware versions (V1, V2, V3)

### Risk: BLE Connection Instability
**Mitigation:** Add retry mechanism and graceful fallback to full DFU

### Risk: Performance Regression
**Mitigation:** Benchmark before/after, ensure partial flash is still 5-10x faster than full DFU

---

## Notes on "Optimized" Implementation

The `PartialFlashingOptimized.swift` file should **NOT** be used because:

1. ❌ Violates iOS CoreBluetooth buffer limits (sends 8 packets without flow control)
2. ❌ Incompatible with device firmware protocol (expects 4-packet blocks)
3. ❌ Causes packet loss and WRITE_FAIL responses
4. ❌ Already proven to fail (reduced from higher values to 2, still failed)

The existing non-optimized implementation is actually **optimal** for the protocol constraints. Any perceived slowness should be addressed through:
- Better BLE signal strength (hardware/environment)
- Device firmware optimizations
- Timeout tuning (not protocol changes)

---

## Conclusion

This plan provides a **proven, reliable path** to enable partial flashing for Calliope V3 by:
- Following the micro:bit Android reference implementation
- Respecting iOS CoreBluetooth best practices (Nordic DFU pattern)
- Adding robust error handling and retry logic
- Maintaining compatibility with device firmware protocol

**Estimated total implementation time:** 3-4 weeks including testing
**Expected outcome:** Reliable partial flashing with 5-10x speedup vs full DFU
