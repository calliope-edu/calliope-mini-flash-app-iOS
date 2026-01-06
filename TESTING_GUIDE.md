# Partial Flashing - Quick Test Guide

## Pre-Test Checklist

- [ ] Build succeeds without errors
- [ ] iOS device running iOS 11+ (for flow control)
- [ ] Calliope V3 hardware available
- [ ] Test hex files prepared (small, medium, large)
- [ ] Xcode Console open for log viewing

---

## Test 1: Basic Partial Flash (5 minutes)

### Setup
1. Open Calliope App
2. Select a small test program (< 10KB)
3. Ensure Calliope V3 is paired

### Execute
1. Tap "Flash" button
2. Wait for completion

### Expected Behavior
✅ Progress bar shows smooth updates
✅ Console shows: "Starting partial flashing"
✅ Console shows: "Received WRITE_SUCCESS (0xFF)"
✅ Completes in 2-4 seconds
✅ Shows "Flash Complete"

### Debug Console Keywords to Look For
```
[PF-...] Starting partial flashing: XX packets to send
[PF-...] Sending block: 4 packets, starting at #0
[PF-...] Received WRITE_SUCCESS (0xFF)
[PF-...] Transmission complete
```

### Failure Indicators
❌ Console shows "Falling back to full flash"
❌ Takes > 60 seconds (means full DFU fallback)
❌ Console shows repeated "Retry #X"
❌ App crashes or hangs

---

## Test 2: Flow Control Test (10 minutes)

### Setup
1. Select large test program (> 100KB)
2. Enable DEBUG mode to see flow control logs

### Execute
1. Flash the large program
2. Watch console for flow control messages

### Expected Behavior
✅ Console shows buffer checks: "canSend=true/false"
✅ Occasional "Buffer full, waiting..." is OK
✅ No "Flow control timeout"
✅ Completes successfully

### Debug Console Keywords
```
[PF-...] Packet 0: canSend=true
[PF-...] Packet 1: canSend=true
[PF-...] Buffer full, waiting... (retry 5/100)
[PF-...] All 4 packets sent, waiting for device ACK
```

### Failure Indicators
❌ "Flow control timeout - buffer stayed full for 1 second"
❌ Repeated buffer full warnings (> 50 retries)

---

## Test 3: Retry Mechanism Test (15 minutes)

### Setup
1. Move Calliope device far from iPhone (weak BLE signal)
2. Or cover Calliope with metal to attenuate signal
3. Select medium test program

### Execute
1. Flash with poor signal conditions
2. Observe retry behavior

### Expected Behavior
✅ May see "Received WRITE_FAIL (0xAA)"
✅ Console shows "Retrying block transmission (attempt 1/3)"
✅ Eventually succeeds or falls back to full DFU
✅ No app crash

### Debug Console Keywords
```
Received WRITE_FAIL (0xAA), attempting retry
Retrying block transmission (attempt 1/3)
Retry #1: Resending 4 packets
write status: FF (block took 0.234s)
```

### Success Criteria
- If signal is very poor: Falls back to full DFU after 3 retries ✅
- If signal is marginal: Succeeds with 1-2 retries ✅
- If signal is good: No retries needed ✅

---

## Test 4: Timeout Test (10 minutes)

### Setup
This is hard to trigger naturally. Look for timeout in retry scenarios.

### Expected Behavior (if it happens)
✅ Console shows "Block transmission timeout (5.0s)"
✅ Triggers retry mechanism
✅ After 3 timeouts: Falls back to full DFU

### Debug Console Keywords
```
Block transmission timeout (5.0s) - no response from device
Timeout waiting for device response
Retrying block transmission (attempt 1/3)
```

---

## Test 5: Connection Loss Test (5 minutes)

### Setup
1. Start flashing a medium file
2. Turn off Calliope device during transmission
3. Or move it out of BLE range

### Execute
1. Flash program
2. Interrupt connection mid-transfer

### Expected Behavior
✅ App detects connection loss
✅ Shows error message
✅ Does not crash or hang
✅ Can reconnect and try again

---

## Test 6: Performance Test (15 minutes)

### Setup
Prepare 3 test files:
- Small: ~5 KB
- Medium: ~30 KB
- Large: ~100 KB

### Execute
For each file:
1. Flash using partial flashing (measure time)
2. Note the time and speed from logs

### Expected Results

| File Size | Expected Time | Expected Speed |
|-----------|---------------|----------------|
| 5 KB      | 2-4 seconds   | 2-3 KB/s       |
| 30 KB     | 6-12 seconds  | 3-5 KB/s       |
| 100 KB    | 15-25 seconds | 4-6 KB/s       |

### Success Criteria
✅ All files complete successfully
✅ Speeds are in expected range
✅ No fallbacks to full DFU
✅ Progress bar is smooth

---

## Test 7: Stress Test (30 minutes)

### Setup
1. Flash same program 10 times in a row
2. Don't disconnect between flashes

### Execute
1. Flash
2. Wait for completion
3. Immediately flash again
4. Repeat 10 times

### Expected Behavior
✅ All 10 flashes succeed
✅ No memory leaks
✅ No performance degradation
✅ Consistent timing

### Failure Indicators
❌ Failures increase with each flash
❌ App becomes slower
❌ Memory usage grows significantly

---

## Common Issues and Solutions

### Issue: "Partial flash failed, resort to full flashing"
**Cause:** Device doesn't support partial flashing, or hex file incompatible
**Solution:** This is expected behavior - full DFU works as fallback

### Issue: "Max retries (3) exceeded"
**Cause:** Poor BLE signal or device firmware issue
**Solution:** 
- Move devices closer
- Ensure device battery is charged
- Check for device firmware bugs

### Issue: "Flow control timeout"
**Cause:** iOS BLE buffer completely full for > 1 second
**Solution:**
- This is rare and indicates iOS issue
- Fallback to full DFU will work
- Report if happens frequently

### Issue: Slow progress (< 1 KB/s)
**Cause:** Poor BLE signal or interference
**Solution:**
- Move closer to device
- Remove interference sources (WiFi, etc.)
- This is expected in poor conditions

---

## Log Collection for Bug Reports

If issues occur, collect:

1. **Full Xcode Console Log**
   - From "Starting partial flashing" to completion/error

2. **Device Info**
   - iOS version
   - iPhone model
   - Calliope hardware version

3. **File Info**
   - File size
   - Source (MakeCode, etc.)

4. **Environment**
   - BLE signal strength (if available)
   - Other BLE devices nearby
   - Distance between devices

---

## Success Metrics

After testing, verify:

- ✅ 95%+ success rate on good BLE signal
- ✅ 5-10x faster than full DFU
- ✅ Graceful fallback on failure
- ✅ No crashes or hangs
- ✅ Good progress feedback
- ✅ Reasonable retry behavior

---

## Next Steps After Testing

If tests pass:
1. ✅ Merge to main branch
2. ✅ Beta test with users
3. ✅ Monitor crash reports
4. ✅ Collect performance metrics

If tests fail:
1. 🔧 Review console logs
2. 🔧 Check specific failure mode
3. 🔧 Adjust timeout/retry parameters if needed
4. 🔧 Report device-specific issues

---

## Performance Monitoring Commands

In Xcode Console, filter logs by:
- `PF-` - All partial flashing debug logs
- `Partial flashing` - High-level progress
- `WRITE_SUCCESS` - Successful blocks
- `WRITE_FAIL` - Failed blocks requiring retry
- `Retry` - Retry attempts
- `fallback` - Fallback to full DFU events

---

## Contact

For issues or questions about this implementation:
- Review: `IMPLEMENTATION_SUMMARY.md`
- Details: `PARTIAL_FLASHING_IMPLEMENTATION_PLAN.md`
- Reference: micro:bit Android implementation
