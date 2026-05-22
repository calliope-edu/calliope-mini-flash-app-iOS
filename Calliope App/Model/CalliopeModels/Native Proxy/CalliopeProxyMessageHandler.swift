//
//  CalliopeProxyMessageHandler.swift
//  Calliope App
//
//  WKScriptMessageHandler for the Calliope Campus native-proxy bridge.
//
//  Receives JSON envelopes `{id, op, args}` from the embedded
//  `@calliope-edu/mini-connection-widget` (see widget src/native-bridge.ts)
//  and dispatches them against the existing iOS BLE + DFU machinery via
//  `MatrixConnectionViewController.instance.usageReadyCalliope`. Pushes
//  events back to JS as `window.__calliopeNative.onMessage('<json>')`.
//
//  Protocol matches the Android `CalliopeProxyBridge`/`BridgeController`
//  pair byte-for-byte — same op names, same event kinds, same envelope.
//

import Foundation
import WebKit
import CoreBluetooth
import NordicDFU

/// Single-channel handler registered as `"calliope"` on a WKWebView's
/// userContentController. Owns no BLE state of its own — it routes ops
/// against the app's existing `usageReadyCalliope`.
final class CalliopeProxyMessageHandler: NSObject, WKScriptMessageHandler {

    static let handlerName = "calliope"

    private weak var webView: WKWebView?

    /// Per-characteristic subscriptions opened via `gattSubscribe`. Cleared
    /// on `gattUnsubscribe` and on the handler's deinit so we don't leak
    /// CBPeripheral notify state when the user leaves the editor.
    private var subscribedCharacteristics: [CBUUID: CBCharacteristic] = [:]

    /// Pending flash reply id — populated on `flash`, resolved by the
    /// progress/state delegate methods below.
    private var pendingFlashReplyId: String?

    /// Tracks whether the current flash is going through the partial-flash
    /// path or full Nordic DFU. Starts as "partial" (matches the legacy
    /// upload() default of trying partial first) and flips to "dfu" the
    /// moment we either explicitly request full DFU (blocks-runtime
    /// detected) or NordicDFU's state machine reports a DFU-only phase.
    /// Forwarded to the widget as `partial: true/false` on flashProgress
    /// events so the UI labels "Schnelles Flashen" vs "Vollständiges
    /// Flashen" correctly.
    private var currentFlashMode: String = "partial"

    /// Holds onto self while a flash is in flight. NordicDFU's delegates
    /// are weak; without this, ARC would tear us down mid-flash.
    private static var inFlightFlasher: CalliopeProxyMessageHandler?

    /// MbitMore service — pxt-blocks-runtime exposes this; pxt-calliope
    /// doesn't (the newer CODAL stub may register the service shell but
    /// leaves STATE all zeros).
    private static let mbitMoreServiceUUID = CBUUID(string: "0b50f3e4-607f-4151-9091-7d008d6ffc5c")
    /// MbitMore STATE characteristic — non-zero data confirms blocks-runtime
    /// is actively running (it fills the buffer with sensor data).
    private static let mbitMoreStateUUID = CBUUID(string: "0b500101-607f-4151-9091-7d008d6ffc5c")

    init(webView: WKWebView) {
        self.webView = webView
    }

    deinit {
        // Clean up any active subscriptions on the live peripheral. Avoids
        // leaving the radio in notify-on state after the editor closes.
        if let cal = activeCalliope() {
            for (_, ch) in subscribedCharacteristics {
                cal.rawNotificationHandlers.removeValue(forKey: ch.uuid)
                cal.peripheral.setNotifyValue(false, for: ch)
            }
        }
        connectPollTimer?.cancel()
        connectPollTimer = nil
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Both `String` and dictionary bodies work — the widget posts a
        // pre-serialized JSON string. Accept both for forward compatibility.
        let envelope: [String: Any]?
        if let str = message.body as? String, let data = str.data(using: .utf8) {
            envelope = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        } else {
            envelope = message.body as? [String: Any]
        }
        guard let env = envelope,
              let id = env["id"] as? String,
              let op = env["op"] as? String else {
            LogNotify.log("[ProxyBridge] malformed envelope")
            return
        }
        let args = env["args"] as? [String: Any] ?? [:]
        dispatch(id: id, op: op, args: args)
    }

    // MARK: - Dispatch

    private func dispatch(id: String, op: String, args: [String: Any]) {
        switch op {
        case "connect": handleConnect(id: id, args: args)
        case "disconnect": handleDisconnect(id: id, args: args)
        case "flash": handleFlash(id: id, args: args)
        case "gattRead": handleGattRead(id: id, args: args)
        case "gattWrite": handleGattWrite(id: id, args: args)
        case "gattSubscribe": handleGattSubscribe(id: id, args: args)
        case "gattUnsubscribe": handleGattUnsubscribe(id: id, args: args)
        case "serialWrite": handleSerialWrite(id: id, args: args)
        default: replyError(id: id, message: "unknown op: \(op)")
        }
    }

    // MARK: - Connect / disconnect

    /// Connect-poll state. iOS doesn't expose a "connect to last paired
    /// device" API the way Android's stored MAC does — the matrix-pairing
    /// UI owns the connection lifecycle. So when the proxy's auto-connect
    /// fires before the user has paired, we don't fail immediately:
    /// nudge the connection icon and poll `activeCalliope()` for a window.
    private var connectPollTimer: DispatchSourceTimer?
    private var pendingConnectReplyId: String?
    /// How many seconds to keep polling for `usageReadyCalliope` before
    /// giving up. Long enough for the user to back out of the editor
    /// (since the matrix connection view isn't visible inside the editor),
    /// pair via the connection icon, and return.
    private static let connectPollSeconds = 60
    private static let connectPollIntervalMs = 1000

    private func handleConnect(id: String, args: [String: Any]) {
        let transport = (args["transport"] as? String) ?? "ble"
        guard transport == "ble" else {
            replyError(id: id, message: "transport=\(transport) not supported in proxy mode (BLE only)")
            return
        }
        emitState(status: "connecting")
        // Cancel any prior connect-poll — a single in-flight attempt is enough.
        cancelConnectPoll()

        if let cal = activeCalliope() {
            // Happy path: device already paired via the legacy connection UI.
            let name = cal.peripheral.name ?? ""
            emitState(
                status: "connected",
                deviceName: name,
                bleCanFlash: true,
                bleCanCommunicate: true,
                bleHasPermission: true
            )
            replyOk(id: id)
            return
        }

        // No paired calliope yet. Bounce the connection icon so the user
        // sees where to pair, then poll for the next minute. We DON'T
        // reply immediately — the widget will keep its "connecting"
        // state visible and the reconnect daemon won't fight us. If
        // the user pairs in the window, we emit `connected` and resolve
        // the reply normally. If they don't, we time out with a helpful
        // error.
        pendingConnectReplyId = id
        DispatchQueue.main.async {
            MatrixConnectionViewController.instance?.animateBounce()
        }
        sendEvent(kind: "log", data: [
            "direction": "info",
            "text": "Bitte oben im Calliope-Symbol einen Calliope mini auswählen und verbinden.",
        ])
        scheduleConnectPoll(remaining: Self.connectPollSeconds)
    }

    private func scheduleConnectPoll(remaining: Int) {
        guard remaining > 0 else {
            let id = pendingConnectReplyId
            pendingConnectReplyId = nil
            emitState(status: "error", errorMessage: "Kein Calliope mini gekoppelt")
            if let id = id {
                replyError(id: id, message: "No Calliope mini paired — please pair one via the connection icon at the top of the app and try again.")
            }
            return
        }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        connectPollTimer = timer
        timer.schedule(deadline: .now() + .milliseconds(Self.connectPollIntervalMs))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.connectPollTimer = nil
            if let cal = self.activeCalliope() {
                let id = self.pendingConnectReplyId
                self.pendingConnectReplyId = nil
                let name = cal.peripheral.name ?? ""
                self.emitState(
                    status: "connected",
                    deviceName: name,
                    bleCanFlash: true,
                    bleCanCommunicate: true,
                    bleHasPermission: true
                )
                if let id = id { self.replyOk(id: id) }
                return
            }
            self.scheduleConnectPoll(remaining: remaining - 1)
        }
        timer.resume()
    }

    private func cancelConnectPoll() {
        connectPollTimer?.cancel()
        connectPollTimer = nil
        pendingConnectReplyId = nil
    }

    private func handleDisconnect(id: String, args: [String: Any]) {
        // Drop any pending connect-poll so it doesn't fire a stale
        // "connected" later.
        cancelConnectPoll()
        // The native proxy doesn't own the BLE connection — the host app
        // does. Forwarding a disconnect into the host would also kill any
        // other UI relying on the connection. Just clear our local
        // subscriptions and report the widget's bleStatus as disconnected
        // for the duration of this editor session.
        if let cal = activeCalliope() {
            for (_, ch) in subscribedCharacteristics {
                cal.rawNotificationHandlers.removeValue(forKey: ch.uuid)
                cal.peripheral.setNotifyValue(false, for: ch)
            }
        }
        subscribedCharacteristics.removeAll()
        emitState(status: "disconnected", deviceName: "")
        replyOk(id: id)
    }

    // MARK: - GATT

    private func handleGattRead(id: String, args: [String: Any]) {
        guard let svcUuid = parseUuid(args["serviceId"]),
              let chUuid = parseUuid(args["characteristicId"]) else {
            replyError(id: id, message: "invalid uuid")
            return
        }
        guard let cal = activeCalliope() else {
            replyError(id: id, message: "not connected")
            return
        }
        guard let ch = findCharacteristic(on: cal.peripheral, service: svcUuid, characteristic: chUuid) else {
            replyError(id: id, message: "characteristic not available")
            return
        }
        cal.read(characteristic: ch) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.replyOk(id: id, data: ["data": data.base64EncodedString()])
                case .failure(let err):
                    self?.replyError(id: id, message: "read failed: \(err.localizedDescription)")
                }
            }
        }
    }

    private func handleGattWrite(id: String, args: [String: Any]) {
        guard let svcUuid = parseUuid(args["serviceId"]),
              let chUuid = parseUuid(args["characteristicId"]) else {
            replyError(id: id, message: "invalid uuid")
            return
        }
        guard let cal = activeCalliope() else {
            replyError(id: id, message: "not connected")
            return
        }
        guard let ch = findCharacteristic(on: cal.peripheral, service: svcUuid, characteristic: chUuid) else {
            replyError(id: id, message: "characteristic not available")
            return
        }
        let withResponse = (args["withResponse"] as? Bool) ?? false
        let data = decodeBase64(args["data"] as? String)
        if withResponse {
            cal.write(data, for: ch) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success: self?.replyOk(id: id)
                    case .failure(let err): self?.replyError(id: id, message: "write failed: \(err.localizedDescription)")
                    }
                }
            }
        } else {
            // Fire-and-forget. CoreBluetooth queues writes-without-response
            // and signals readiness via peripheralIsReady; we don't need
            // to mirror that flow for the proxy — the widget treats
            // unconfirmed writes as best-effort.
            cal.peripheral.writeValue(data, for: ch, type: .withoutResponse)
            replyOk(id: id)
        }
    }

    private func handleGattSubscribe(id: String, args: [String: Any]) {
        guard let svcUuid = parseUuid(args["serviceId"]),
              let chUuid = parseUuid(args["characteristicId"]) else {
            replyError(id: id, message: "invalid uuid")
            return
        }
        guard let cal = activeCalliope() else {
            replyError(id: id, message: "not connected")
            return
        }
        guard let ch = findCharacteristic(on: cal.peripheral, service: svcUuid, characteristic: chUuid) else {
            replyError(id: id, message: "characteristic not available")
            return
        }
        let serviceIdAny: Any = args["serviceId"] ?? svcUuid.uuidString
        let charIdAny: Any = args["characteristicId"] ?? chUuid.uuidString
        // Install the raw notify handler on BLECalliope BEFORE enabling
        // notifications, so we don't drop the first packet between
        // setNotifyValue and the first didUpdateValueFor callback.
        cal.rawNotificationHandlers[ch.uuid] = { [weak self] data in
            self?.sendEvent(kind: "gattNotify", data: [
                "serviceId": serviceIdAny,
                "characteristicId": charIdAny,
                "data": data.base64EncodedString(),
            ])
        }
        subscribedCharacteristics[ch.uuid] = ch
        cal.setNotify(characteristic: ch, true) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success: self?.replyOk(id: id)
                case .failure(let err):
                    cal.rawNotificationHandlers.removeValue(forKey: ch.uuid)
                    self?.subscribedCharacteristics.removeValue(forKey: ch.uuid)
                    self?.replyError(id: id, message: "subscribe failed: \(err.localizedDescription)")
                }
            }
        }
    }

    private func handleGattUnsubscribe(id: String, args: [String: Any]) {
        guard let svcUuid = parseUuid(args["serviceId"]),
              let chUuid = parseUuid(args["characteristicId"]) else {
            replyError(id: id, message: "invalid uuid")
            return
        }
        guard let cal = activeCalliope() else {
            replyOk(id: id)
            return
        }
        if let ch = subscribedCharacteristics.removeValue(forKey: chUuid)
            ?? findCharacteristic(on: cal.peripheral, service: svcUuid, characteristic: chUuid) {
            cal.rawNotificationHandlers.removeValue(forKey: ch.uuid)
            cal.peripheral.setNotifyValue(false, for: ch)
        }
        replyOk(id: id)
    }

    // MARK: - Serial (UART)

    private static let uartServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private static let uartRxUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    private func handleSerialWrite(id: String, args: [String: Any]) {
        guard let cal = activeCalliope() else {
            replyError(id: id, message: "not connected")
            return
        }
        guard let ch = findCharacteristic(
            on: cal.peripheral,
            service: Self.uartServiceUUID,
            characteristic: Self.uartRxUUID
        ) else {
            replyError(id: id, message: "UART RX characteristic not available")
            return
        }
        let data = decodeBase64(args["data"] as? String)
        cal.peripheral.writeValue(data, for: ch, type: .withoutResponse)
        replyOk(id: id)
    }

    // MARK: - Flash

    private func handleFlash(id: String, args: [String: Any]) {
        guard let hex = args["hex"] as? String, !hex.isEmpty else {
            replyError(id: id, message: "flash: empty hex")
            return
        }
        let rawName = (args["name"] as? String) ?? "project"
        let safeName = rawName.replacingOccurrences(
            of: "[^A-Za-z0-9._-]+",
            with: "-",
            options: .regularExpression
        )
        let argForceFullDfu = (args["forceFullDfu"] as? Bool) ?? false

        // Persist hex to a temp file so we can hand it to the existing
        // upload pipeline as a Hex (HexFile expects a URL).
        //
        // Intel HEX is pure ASCII (0-9, A-F, ':', \r, \n). UTF-8 is byte-
        // identical for that range, but doesn't throw if a stray BOM or
        // non-ASCII char slips in — the partial-flash service searches
        // for PXT_MAGIC as a text substring, so silent corruption would
        // skip the partial-flash path entirely. UTF-8 matches the Android
        // bridge's encoding choice for the same reason.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bridge-flash", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let tmpURL = tmpDir.appendingPathComponent("\(safeName).hex")
        do {
            try hex.write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            replyError(id: id, message: "could not write hex: \(error.localizedDescription)")
            return
        }

        guard let cal = activeCalliope() else {
            replyError(id: id, message: "not connected")
            return
        }

        // Drop our notify subscriptions so partial-flash / DFU isn't fighting
        // for the radio.
        for (_, ch) in subscribedCharacteristics {
            cal.rawNotificationHandlers.removeValue(forKey: ch.uuid)
            cal.peripheral.setNotifyValue(false, for: ch)
        }
        subscribedCharacteristics.removeAll()

        let hexFile = HexFile(url: tmpURL, name: safeName, date: Date())
        pendingFlashReplyId = id
        Self.inFlightFlasher = self

        // Probe MbitMore STATE before flashing. If the device is running
        // pxt-blocks-runtime, the DAL hash matches pxt-calliope (both share
        // the underlying CODAL DAL) but the PXT runtime in the gap between
        // DAL region and MakeCode region differs — partial flash would
        // only update the user-program area and leave the runtime intact,
        // producing a broken hybrid. Same protocol blind spot as Android.
        // Detect via STATE content (non-zero = real blocks-runtime, not
        // just the CODAL stub) and force full DFU on hit.
        probeBlocksRuntime(on: cal) { [weak self] isBlocksRuntime in
            guard let self = self else { return }
            let forceFullDfu = argForceFullDfu || isBlocksRuntime
            if isBlocksRuntime && !argForceFullDfu {
                self.sendEvent(kind: "log", data: [
                    "direction": "info",
                    "text": "Blocks-Runtime erkannt — vollständiger DFU statt partial-flash",
                ])
            }
            self.currentFlashMode = forceFullDfu ? "dfu" : "partial"
            self.emitFlashProgress(phase: "prepare", progress: 0)
            self.beginFlash(
                id: id,
                cal: cal,
                hexFile: hexFile,
                forceFullDfu: forceFullDfu
            )
        }
    }

    /// Continues handleFlash after the blocks-runtime probe returns.
    /// Wires the partial-flash disconnect callback, sets the override
    /// flag on the connected calliope (consumed by upload), and calls
    /// upload. Split from handleFlash so the async probe completion can
    /// inject `forceFullDfu` before we touch the BLE stack.
    private func beginFlash(id: String, cal: BLECalliope, hexFile: HexFile, forceFullDfu: Bool) {
        // Mirror the legacy FirmwareUpload.upload setup so partial-flash
        // works identically here: enable DFU-mode on the connection view,
        // and forward the partial-flash mid-flow disconnect request to
        // the host's connector. Without these the partial-flash post-reboot
        // step would stall.
        MatrixConnectionViewController.instance?.enableDfuMode(mode: true)
        if let flashable = cal as? FlashableBLECalliope {
            flashable.requestDisconnectCallback = {
                MatrixConnectionViewController.instance?.connector.disconnectForReboot()
            }
            flashable.forceFullDfuForNextUpload = forceFullDfu
        }

        do {
            try cal.upload(file: hexFile, progressReceiver: self, statusDelegate: self, logReceiver: self)
        } catch {
            pendingFlashReplyId = nil
            Self.inFlightFlasher = nil
            MatrixConnectionViewController.instance?.enableDfuMode(mode: false)
            replyError(id: id, message: "upload failed: \(error.localizedDescription)")
        }
    }

    /// Probe MbitMore STATE on the connected calliope and call `onResult`
    /// with `true` if the device is running pxt-blocks-runtime (STATE
    /// returns non-zero bytes), `false` otherwise (zeros, characteristic
    /// missing, read failed, or 1.5 s timeout). Mirrors the widget's
    /// `program-type.ts probeBle` heuristic.
    private func probeBlocksRuntime(on cal: BLECalliope, onResult: @escaping (Bool) -> Void) {
        guard let ch = findCharacteristic(
            on: cal.peripheral,
            service: Self.mbitMoreServiceUUID,
            characteristic: Self.mbitMoreStateUUID
        ) else {
            onResult(false)
            return
        }
        // Latch the result so neither the read callback nor the timeout
        // can fire it twice (e.g. a slow read that returns just after
        // the timer fired).
        var settled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !settled {
                settled = true
                onResult(false)
            }
        }
        cal.read(characteristic: ch) { result in
            DispatchQueue.main.async {
                if settled { return }
                settled = true
                switch result {
                case .success(let data):
                    let anyNonZero = data.contains { $0 != 0 }
                    onResult(anyNonZero)
                case .failure:
                    onResult(false)
                }
            }
        }
    }

    // MARK: - Helpers

    private func activeCalliope() -> BLECalliope? {
        return MatrixConnectionViewController.instance?.usageReadyCalliope as? BLECalliope
    }

    private func parseUuid(_ any: Any?) -> CBUUID? {
        if let s = any as? String { return CBUUID(string: s) }
        if let n = any as? Int { return CBUUID(string: String(format: "%04X", n)) }
        if let n = any as? UInt { return CBUUID(string: String(format: "%04X", n)) }
        return nil
    }

    private func findCharacteristic(
        on peripheral: CBPeripheral,
        service: CBUUID,
        characteristic: CBUUID
    ) -> CBCharacteristic? {
        guard let svc = peripheral.services?.first(where: { $0.uuid == service }) else {
            return nil
        }
        return svc.characteristics?.first(where: { $0.uuid == characteristic })
    }

    private func decodeBase64(_ s: String?) -> Data {
        guard let s = s, !s.isEmpty, let d = Data(base64Encoded: s) else { return Data() }
        return d
    }

    // MARK: - Reply / event emission

    private func replyOk(id: String, data: [String: Any]? = nil) {
        var msg: [String: Any] = ["id": id, "type": "reply"]
        if let data = data { msg["data"] = data }
        post(msg)
    }

    private func replyError(id: String, message: String) {
        post(["id": id, "type": "reply", "error": message])
    }

    private func sendEvent(kind: String, data: [String: Any]) {
        post(["type": "event", "kind": kind, "data": data])
    }

    private func emitState(
        status: String,
        deviceName: String? = nil,
        errorMessage: String? = nil,
        bleCanFlash: Bool? = nil,
        bleCanCommunicate: Bool? = nil,
        bleHasPermission: Bool? = nil
    ) {
        var d: [String: Any] = ["transport": "ble", "status": status]
        if let deviceName = deviceName { d["deviceName"] = deviceName }
        if let errorMessage = errorMessage { d["errorMessage"] = errorMessage }
        if let bleCanFlash = bleCanFlash { d["bleCanFlash"] = bleCanFlash }
        if let bleCanCommunicate = bleCanCommunicate { d["bleCanCommunicate"] = bleCanCommunicate }
        if let bleHasPermission = bleHasPermission { d["bleHasPermission"] = bleHasPermission }
        sendEvent(kind: "state", data: d)
    }

    private func emitFlashProgress(phase: String, progress: Int) {
        sendEvent(kind: "flashProgress", data: [
            "transport": "ble",
            "phase": phase,
            "progress": progress,
            "partial": currentFlashMode == "partial",
        ])
    }

    private func post(_ msg: [String: Any]) {
        guard let webView = self.webView else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: msg),
              let json = String(data: data, encoding: .utf8) else { return }
        // Embed the JSON string as a single-quoted JS literal; escape backslash
        // and single-quote to keep the literal valid. The widget's
        // __calliopeNative.onMessage accepts string or object — it
        // re-parses strings with JSON.parse.
        let escaped = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        let js = "if(window.__calliopeNative)window.__calliopeNative.onMessage('\(escaped)');"
        DispatchQueue.main.async {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func finishFlash(success: Bool, error: String?) {
        let id = pendingFlashReplyId
        pendingFlashReplyId = nil
        Self.inFlightFlasher = nil
        MatrixConnectionViewController.instance?.enableDfuMode(mode: false)
        if success {
            emitFlashProgress(phase: "finalising", progress: 100)
            sendEvent(kind: "flashDone", data: [:])
        }
        if let id = id {
            if success { replyOk(id: id) } else { replyError(id: id, message: error ?? "flash failed") }
        }
    }
}

// MARK: - DFU delegates

extension CalliopeProxyMessageHandler: DFUProgressDelegate {
    func dfuProgressDidChange(
        for part: Int,
        outOf totalParts: Int,
        to progress: Int,
        currentSpeedBytesPerSecond: Double,
        avgSpeedBytesPerSecond: Double
    ) {
        emitFlashProgress(phase: "flashing", progress: progress)
    }
}

extension CalliopeProxyMessageHandler: DFUServiceDelegate {
    func dfuStateDidChange(to state: DFUState) {
        // Any NordicDFU state callback means we're on the full-DFU path —
        // partial flash never goes through NordicDFU. Flip the mode flag
        // so subsequent flashProgress events advertise `partial: false`.
        // (For partial flash, progress comes from FlashableBLECalliope's
        // own partial-flash machinery, not from DFUServiceDelegate.)
        currentFlashMode = "dfu"
        switch state {
        case .connecting, .starting:
            emitFlashProgress(phase: "prepare", progress: 0)
        case .enablingDfuMode:
            emitFlashProgress(phase: "reboot", progress: 0)
        case .uploading:
            emitFlashProgress(phase: "flashing", progress: 0)
        case .validating:
            emitFlashProgress(phase: "finalising", progress: 100)
        case .completed:
            finishFlash(success: true, error: nil)
        case .aborted:
            finishFlash(success: false, error: "flash aborted")
        case .disconnecting:
            break
        @unknown default:
            break
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        finishFlash(success: false, error: "DFU error \(error.rawValue): \(message)")
    }
}

extension CalliopeProxyMessageHandler: LoggerDelegate {
    func logWith(_ level: LogLevel, message: String) {
        // Forward only ERROR-level logs as proxy log events so the widget
        // doesn't flood its panel with low-level DFU chatter.
        guard level == .error else { return }
        sendEvent(kind: "log", data: ["direction": "error", "text": message])
    }
}
