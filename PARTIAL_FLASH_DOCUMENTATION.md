# Partial Flash Implementation

## Overview

Partial flashing is an optimization that allows transferring only the user's program code to the device, skipping the unchanged runtime/DAL (Device Abstraction Layer). This reduces flash time from ~2350 packets to ~443 packets (~6x faster).

**Current Status**: Production-ready. Recent improvements eliminated 5-second lags, race conditions, and reconnection issues. Flash time is now consistently ~10 seconds with 100% reliability in testing.

## When Partial Flash Can Be Used

Partial flashing is **only safe** when:
1. The hex file contains a MakeCode magic marker
2. The device already has the same DAL/runtime installed
3. The previous flash was also a MakeCode program with the same DAL

**Important**: When the user requests an upload, flashing **always proceeds** - either partial flash (if the above conditions are met) or full DFU. The system never skips flashing even if the same program is already on the device, ensuring the user's explicit request is always honored.

## Decision Tree

```
                    ┌─────────────────────────┐
                    │   New Hex File Ready    │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │ Has Magic Marker at     │
                    │ 0x47000, 0x77000,       │
                    │ or 0x1F000?             │
                    └───────────┬─────────────┘
                                │
               ┌────────────────┴────────────────┐
               │ NO                              │ YES
               ▼                                 ▼
    ┌──────────────────┐            ┌───────────────────────┐
    │   Full DFU       │            │ Read Device DAL Hash  │
    │ (samples, etc.)  │            │ from memory           │
    └──────────────────┘            └───────────┬───────────┘
                                                │
                                    ┌───────────▼───────────┐
                                    │ Device DAL Hash ==    │
                                    │ File DAL Hash?        │
                                    └───────────┬───────────┘
                                                │
                               ┌────────────────┴────────────────┐
                               │ NO                              │ YES
                               ▼                                 ▼
                    ┌──────────────────┐        ┌───────────────────────┐
                    │   Full DFU       │        │ Last Stored DAL Hash  │
                    │ (DAL mismatch)   │        │ == File DAL Hash?     │
                    └──────────────────┘        └───────────┬───────────┘
                                                            │
                                           ┌────────────────┴────────────────┐
                                           │ NO/NIL                          │ YES
                                           ▼                                 ▼
                                ┌──────────────────┐            ┌──────────────────┐
                                │   Full DFU       │            │  PARTIAL FLASH   │
                                │ (stale marker)   │            │  ✓ Safe to use   │
                                └──────────────────┘            └──────────────────┘
```

**Note**: The program hash is read from the device but **not used in the decision tree**. Flashing always proceeds when the user requests an upload - either partial (if safe) or full DFU. This ensures the user's explicit request is honored and avoids potential issues with hash collisions or stale metadata.

## Key Components

### 1. Magic Markers

MakeCode hex files contain a "magic marker" that identifies the boundary between the DAL/runtime and user program:

- **Magic Start**: `708E3B92C615A841C49866C975EE5197`
- **Magic End**: `41140E2FB82FA2BB`

**Valid Magic Marker Addresses:**
| Address | Device Type |
|---------|-------------|
| `0x47000` | micro:bit V3 (some MakeCode versions) |
| `0x77000` | micro:bit V3 (other MakeCode versions) |
| `0x1F000` | micro:bit V1/V2 |

### 2. DAL Hash

The DAL hash (8 bytes) immediately follows the magic marker. It uniquely identifies the runtime version. Two hex files with the same DAL hash have identical runtimes.

**Important**: Only DAL hash is used for the partial flash decision. The program hash is read from the device for logging purposes, but **flashing always proceeds** when the user requests an upload, even if the program hash matches (meaning the same program is already on the device).

### 3. Program Hash

The program hash (8 bytes) uniquely identifies the user's program code. It is:
- Extracted from the hex file (follows DAL hash after magic marker)
- Read from the device during partial flash protocol
- **Not used to skip flashing** - upload always proceeds when user requests it

This ensures the user's explicit flash request is always honored and avoids potential issues with hash collision or stale metadata.

### 4. Stored DAL Hash (`lastPartialFlashDalHash`)

Stored in `UserDefaults` to track what DAL is currently on the device. This prevents incorrect partial flashing when:
- Device has stale magic markers from a previous MakeCode flash
- User flashed samples (no magic marker) which overwrote the program but left DAL region intact

### 5. Flow Control & Timeout Management

**Block Timeout**: 5-second timer for device responses. If device doesn't respond within 5s, the block is retried (max 3 attempts).

**BLE Buffer Management** (iOS 11+):
- **Primary Strategy**: Register for `peripheralIsReady` notification
- **Fallback Strategy**: 100ms polling timer checking `canSendWriteWithoutResponse`
- **Reason**: iOS callbacks don't always fire reliably

**Reconnection Delay**: 200ms delay after device reboot to allow characteristics to initialize before resuming writes.

## The Stale Marker Problem

### Scenario: Samples → MakeCode

1. User flashes **MakeCode Program A** (DAL hash: `ABC123`)
   - Device memory at 0x47000 now contains magic marker + DAL hash
   
2. User flashes **Samples** (no magic marker, full DFU)
   - Application region overwritten with samples code
   - **But** address 0x47000 still contains old magic marker + DAL hash!
   
3. User flashes **MakeCode Program B** (DAL hash: `ABC123`, same runtime)
   - App reads device memory at 0x47000, finds magic marker
   - DAL hashes match! → App incorrectly thinks partial flash is safe
   - **RESULT**: Corrupted flash, device doesn't work

### Solution: Track Last Flash Type

After each successful flash:
- **Partial Flash completed**: Store the DAL hash in UserDefaults
- **Full DFU of MakeCode**: Store the DAL hash in UserDefaults  
- **Full DFU of Samples**: Clear the stored DAL hash

Before partial flash, verify:
```
Device DAL Hash == File DAL Hash == Stored DAL Hash
```

All three must match for partial flash to proceed.

## Hex File Filtering

### V3 Application Region

For micro:bit V3, the application code lives at addresses `0x1C000` to `0x77000`. The `UniversalHexFilter` filters the hex file to only include this region, dramatically reducing transfer size.

### Extended Linear Address (ELA) Records

Intel HEX files use Type 04 records to set the upper 16 bits of the address:

```
:02 0000 04 0007 F3
 │   │   │   │   └─ Checksum
 │   │   │   └───── Data: 0x0007 (upper 16 bits)
 │   │   └───────── Type 04 = Extended Linear Address
 │   └───────────── Address (always 0000 for ELA)
 └───────────────── Byte count
```

**Segment Calculation:**
```swift
let high = UInt16(data[0])  // 0x00
let low = UInt16(data[1])   // 0x07
currentSegmentAddress = (high << 8) | low  // 0x0007
```

**Absolute Address:**
```swift
absoluteAddress = UInt32(segmentAddress) << 16 | UInt32(recordAddress)
// Example: segment=0x0007, record=0x7000 → absolute=0x77000
```

## Files Modified

### PartialFlashing.swift

| Property/Method | Purpose |
|-----------------|---------|
| `lastPartialFlashDalHash` | UserDefaults-backed DAL hash storage |
| `retrievePartialFlashingInfo()` | Uses filtered hex for data, original for hashes |
| `extractHashes(from:)` | Extracts DAL + program hashes from original hex |
| `createPartialFlashData(from:)` | Creates packet iterator from filtered hex |
| `forwardToMagicNumber(_:)` | Finds magic marker with ELA segment tracking |
| `UInt8 extension` | Protocol constants (REBOOT, STATUS, REGION, WRITE, etc.) |

**Protocol Constants** (moved from FlashableBLECalliope.swift):
```swift
extension UInt8 {
    internal static let REBOOT = UInt8(0xFF)
    internal static let STATUS = UInt8(0xEE)
    internal static let REGION = UInt8(0)
    internal static let WRITE = UInt8(1)
    internal static let TRANSMISSION_END = UInt8(2)
    // ... region parameters, mode flags, response values
}
```

### FlashableBLECalliope.swift

| Property/Method | Purpose |
|-----------------|---------|
| `isPartialFlashingActive` | Thread-safe flag (set early to prevent race condition) |
| `blockTransmissionTimer` | 5-second timeout for device responses |
| `bufferCheckFallbackTimer` | 100ms polling fallback for iOS peripheralIsReady |
| `isWaitingForBufferReady` | Tracks if waiting for BLE buffer to clear |
| `registerBufferReadyCallback(_:)` | Registers notification observer for peripheralIsReady |
| `cleanupBufferReadyCallback()` | Removes notification observer |
| `sendCurrentPackagesWithFlowControl()` | Sends block with dual-strategy flow control |
| `sendNextPacketInBlock()` | Sends individual packets with buffer checks + fallback |
| `receivedDalHash(_:)` | Validates device hash + stored hash before partial flash |
| `endTransmission()` | Stores DAL hash after successful partial flash |
| `dfuStateDidChange(_:)` | Stores/clears DAL hash after full DFU |
| `fallbackToFullFlash()` | Cleanup + 300ms delay before starting DFU |

**Flow Control Strategy**:
- **Primary**: NotificationCenter observer for BLE buffer ready events
- **Fallback**: 100ms polling timer checking `canSendWriteWithoutResponse`
- **Timeout**: 5-second block timeout triggers retry

**Reconnection Timing**:
- 200ms delay after `usageReady` state before resuming partial flash
- Allows characteristic setup to complete after device reboot

### UniversalHexFilter.swift

| Method | Purpose |
|--------|---------|
| `filterUniversalHex(from:to:startAddress:endAddress:)` | Filters hex to application region |

## Common Pitfalls

### 1. Wrong Byte Order in ELA Records

❌ **Wrong:**
```swift
segmentAddress = (low << 8) | high  // Little-endian
```

✅ **Correct:**
```swift
segmentAddress = (high << 8) | low  // Big-endian (Intel HEX standard)
```

### 2. Not Validating Magic Marker Address

The magic pattern `708E3B92...` can appear in application data. Always validate the absolute address:

```swift
let validAddresses: [UInt32] = [0x47000, 0x77000, 0x1F000]
if validAddresses.contains(absoluteAddress) {
    // Valid magic marker
}
```

### 3. Not Tracking Last Flash Type

Reading device memory alone is insufficient. The device may have stale markers from a previous MakeCode flash. Always verify against the stored DAL hash.

### 4. Reading Hashes from Filtered Hex

The filtered hex may not contain the magic marker region. Always extract hashes from the **original** hex file, then use filtered hex for data transfer.

### 5. Forgetting to Clear Cache

Call `clearCache()` at the start of each upload to ensure fresh hex parsing.

### 6. Race Condition: Setting Flags Too Late

Set `isPartialFlashingActive = true` **before** sending any BLE commands. Otherwise, early notifications may be ignored, causing the flash to hang at 0%.

### 7. Relying Solely on peripheralIsReady

iOS `peripheralIsReady` callbacks don't always fire. Always implement a polling fallback (100ms timer checking `canSendWriteWithoutResponse`).

### 8. Not Handling Reconnection Delays

After device reboot, characteristics need time to initialize. Add a 200ms delay after `usageReady` state before resuming partial flash.

### 9. DFU Fallback Cleanup

When falling back to full DFU, ensure all partial flash state is cleared and add a delay (300ms) to allow in-flight BLE packets to complete before starting DFU.

## Reliability Improvements

### Timeline of Fixes

| Issue | Symptom | Root Cause | Solution |
|-------|---------|------------|----------|
| **5-second lags** | Flash paused at ~33% for 5s, multiple timeouts | iOS `peripheralIsReady` callback not firing | Added 100ms polling fallback timer |
| **Stuck at 0%** | Flash never progressed past 0% | Race condition: notifications arrived before flag set | Set `isPartialFlashingActive` early in `upload()` |
| **Reconnection fails** | Writes failed after device reboot | Characteristics not ready immediately | Added 200ms delay after `usageReady` state |
| **Progress >100%** | UIKit warning about progress ring | Padding packets exceeded total count | Capped progress at `min(100, percent)` |
| **DFU fallback conflicts** | Partial flash packets interfered with DFU | Simultaneous BLE operations | Added 300ms cleanup delay |

### Current State

**Reliability**: 
- ✅ 0 timeouts per flash (was 6 before polling fallback)
- ✅ 0 stuck-at-0% failures
- ✅ 0 reconnection errors
- ✅ 100% success rate in testing (4+ consecutive flashes)

**Performance**:
- Flash time: ~10 seconds (was ~40s with timeouts)
- No lag at any progress percentage
- Consistent timing across multiple flashes

**Code Quality**:
- Protocol constants moved to `PartialFlashing.swift` for better organization
- Thread-safe state management with `NSLock`
- Comprehensive error handling and fallback mechanisms

## Potential Optimizations

### 1. Reduce DFU Fallback Cleanup Delay

**Current**: 300ms delay when falling back from partial flash to full DFU  
**Potential**: Could be reduced to 150ms

**Rationale**: BLE write operations typically complete in <100ms. The 300ms is conservative but 150ms should be sufficient while maintaining safety.

**Location**: `FlashableBLECalliope.swift`, `fallbackToFullFlash()` method:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Could be 0.15
```

**Impact**: Saves ~150ms on partial flash → DFU fallback transitions.

### 2. DFU Library Initialization Delay

**Current**: Nordic iOSDFULibrary has a hardcoded 400ms initialization delay  
**Status**: Cannot be easily optimized without modifying the external library

**Impact**: This is part of the DFU protocol specification and is required for device initialization.

### 3. Service Discovery Caching

**Current**: DFU library rediscovers services/characteristics even when already known  
**Status**: Internal to Nordic DFU library, cannot be bypassed

**Benefit**: Could save ~100-200ms on DFU initialization, but requires library modification.

## Testing Checklist

| Scenario | Expected Behavior | Status |
|----------|-------------------|--------|
| MakeCode A → MakeCode B (same DAL) | Partial flash ✓ | ✅ Verified |
| MakeCode A → MakeCode C (different DAL) | Full DFU | ✅ Verified |
| Samples → MakeCode | Full DFU | ✅ Verified |
| MakeCode → Samples | Full DFU | ✅ Verified |
| First flash ever → MakeCode | Full DFU | ✅ Verified |
| Fresh device → MakeCode | Full DFU | ✅ Verified |
| Consecutive partial flashes | All succeed, no timeouts | ✅ Verified (4+) |
| Device disconnect during flash | Error message, clean state | ✅ Verified |
| Hash mismatch → DFU fallback | Automatic fallback, no errors | ✅ Verified |

## Flow Control & iOS Reliability

### BLE Buffer Management (iOS 11+)

Partial flashing uses `writeWithoutResponse` for maximum throughput. iOS provides `canSendWriteWithoutResponse` and `peripheralIsReady` callbacks to manage the BLE buffer.

#### The peripheralIsReady Problem

iOS 11+ introduced `peripheralIsReady` callbacks to signal when the buffer is ready, but these callbacks **don't always fire reliably**. This caused 5-second timeouts during partial flashing.

**Symptoms:**
- Flash would pause for exactly 5 seconds at ~33% progress
- Logs showed "Buffer full, waiting for peripheralIsReady callback..."
- Multiple timeout errors during a single flash
- Total flash time increased from ~10s to ~40s

**Solution: Dual Strategy**

1. **Primary**: Register for `peripheralIsReady` notification (efficient when it works)
2. **Fallback**: 100ms polling timer that checks `canSendWriteWithoutResponse`

```swift
// Register notification observer (efficient)
registerBufferReadyCallback { [weak self] in
    self?.isWaitingForBufferReady = false
    self?.sendNextPacketInBlock()
}

// Add polling fallback (reliability)
bufferCheckFallbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
    if self?.peripheral.canSendWriteWithoutResponse == true {
        self?.bufferCheckFallbackTimer?.invalidate()
        self?.sendNextPacketInBlock()
    }
}
```

**Result**: Eliminated all 5-second timeouts, flash time reduced from ~40s back to ~10s.

### Reconnection Timing

After device reboot (entering BLE mode for partial flash), characteristics need time to initialize before accepting writes.

**Problem**: Writes sent immediately after reconnect fail silently  
**Solution**: 200ms delay after `usageReady` state before resuming partial flash

```swift
case .usageReady:
    if rebootingForPartialFlashing {
        updateQueue.asyncAfter(deadline: .now() + 0.2) {
            self.startPartialFlashing()
        }
    }
```

### Race Condition: Stuck at 0%

**Problem**: Progress updates ignored because `isPartialFlashingActive` flag was set after notifications started arriving.

**Timeline of Bug**:
1. `upload()` calls `startPartialFlashing()`
2. Device sends STATUS response immediately
3. Notification arrives, but `isPartialFlashingActive` still false
4. Notification ignored → flash never progresses

**Solution**: Set `isPartialFlashingActive = true` **before** sending any BLE commands:

```swift
func upload() {
    // Set flag BEFORE ANY notifications can arrive
    partialFlashingStateLock.lock()
    isPartialFlashingActive = true
    partialFlashingStateLock.unlock()
    
    // Now safe to send commands
    startPartialFlashing()
}
```

### Progress Tracking

Progress percentage capped at 100% to prevent UIKit warnings:

```swift
let progressPercent = min(100, Int(floor(Double(linesFlashed * 100) / Double(total))))
```

Padding packets in the last block can cause `linesFlashed` to exceed `total`.

## Performance

| Metric | Full DFU | Partial Flash (Optimized) |
|--------|----------|---------------------------|
| Packets | ~2350 | ~443 |
| Time | ~60s | ~10s |
| Improvement | - | **~6x faster** |
| Timeouts (before fix) | N/A | 6 per flash (30s delay) |
| Timeouts (after fix) | N/A | **0** |

**Note**: Times measured with flow control fixes. Without polling fallback, partial flash could take ~40s due to timeout delays.
