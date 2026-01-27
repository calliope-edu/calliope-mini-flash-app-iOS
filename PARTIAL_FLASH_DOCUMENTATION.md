# Partial Flash Implementation

## Overview

Partial flashing is an optimization that allows transferring only the user's program code to the device, skipping the unchanged runtime/DAL (Device Abstraction Layer). This reduces flash time from ~2350 packets to ~443 packets (~5x faster).

## When Partial Flash Can Be Used

Partial flashing is **only safe** when:
1. The hex file contains a MakeCode magic marker
2. The device already has the same DAL/runtime installed
3. The previous flash was also a MakeCode program with the same DAL

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

### 3. Stored DAL Hash (`lastPartialFlashDalHash`)

Stored in `UserDefaults` to track what DAL is currently on the device. This prevents incorrect partial flashing when:
- Device has stale magic markers from a previous MakeCode flash
- User flashed samples (no magic marker) which overwrote the program but left DAL region intact

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

### HexParser.swift

| Property/Method | Purpose |
|-----------------|---------|
| `lastPartialFlashDalHash` | UserDefaults-backed DAL hash storage |
| `retrievePartialFlashingInfo()` | Uses filtered hex for data, original for hashes |
| `extractHashes(from:)` | Extracts DAL + program hashes from original hex |
| `createPartialFlashData(from:)` | Creates packet iterator from filtered hex |
| `forwardToMagicNumber(_:)` | Finds magic marker with ELA segment tracking |

### FlashableBLECalliope.swift

| Method | Purpose |
|--------|---------|
| `receivedDalHash(_:)` | Validates device hash + stored hash before partial flash |
| `endTransmission()` | Stores DAL hash after successful partial flash |
| `dfuStateDidChange(_:)` | Stores/clears DAL hash after full DFU |

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

## Testing Checklist

| Scenario | Expected Behavior |
|----------|-------------------|
| MakeCode A → MakeCode B (same DAL) | Partial flash ✓ |
| MakeCode A → MakeCode C (different DAL) | Full DFU |
| Samples → MakeCode | Full DFU |
| MakeCode → Samples | Full DFU |
| First flash ever → MakeCode | Full DFU |
| Fresh device → MakeCode | Full DFU |

## Performance

| Metric | Full DFU | Partial Flash |
|--------|----------|---------------|
| Packets | ~2350 | ~443 |
| Improvement | - | ~5x faster |
