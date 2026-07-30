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

    // MARK: Host connection mirroring state

    /// NotificationCenter observer tokens for the host app's BLE connection
    /// lifecycle (`usageReadyNotificationName` / `disconnectedNotificationName`,
    /// posted by `DiscoveredDevice`). The proxy owns no BLE state — it mirrors
    /// the app's connection into the widget so the campus reflects "connected" /
    /// "disconnected" the instant the app does. See `installConnectionObservers`.
    private var connectionObservers: [NSObjectProtocol] = []

    /// What we last told the widget: `true` after we emit a `connected` state,
    /// `false` after `disconnected`. Guards redundant emits and drives mirroring.
    private var bridgeConnected = false

    /// Debounce timer for emitting `disconnected`. A brief drop (post-flash
    /// reboot, transient out-of-range the app auto-recovers from) must not
    /// flicker the campus red→green — we wait out a window and only emit
    /// `disconnected` if the app still has no usage-ready calliope when it fires.
    private var disconnectDebounceTimer: DispatchSourceTimer?

    /// While set in the future, disconnect emission is held off longer than the
    /// normal debounce: a flash reboots the mini, and reconnect + service
    /// discovery can take several seconds. Set on flash completion.
    private var flashSettleDeadline: Date?

    /// Normal debounce before reflecting a disconnect (coalesces a quick
    /// reboot/reconnect). The flash-settle window extends this after a flash.
    private static let disconnectDebounceSeconds = 4.0
    private static let flashSettleSeconds = 15.0

    // MARK: Reconnect-before-flash state

    /// Friendly name (CVCVC) of the mini we last reported `connected`. Used to
    /// re-target it during a reconnect-before-flash when the previous program
    /// turned BLE off and the link went stale.
    private var lastFriendlyName: String?

    /// Poll timer driving a reconnect-before-flash attempt. A flash request that
    /// arrives with no live connection (typical after flashing a no-BLE program:
    /// MicroPython, or MakeCode with the radio extension) re-opens the link —
    /// scanning, connecting to the known mini, prompting for A+B+Reset if it
    /// isn't advertising — then flashes once usage-ready.
    private var flashReconnectTimer: DispatchSourceTimer?

    /// How long to optimistically try to reconnect before surfacing the
    /// "put your mini in Bluetooth mode (A+B+Reset)" prompt to the user.
    private static let flashReconnectOptimisticSeconds = 8.0
    /// Absolute cap on the reconnect-before-flash wait. Kept under the widget's
    /// 180 s `flash` bridge timeout so we reply with a clean error first.
    private static let flashReconnectMaxSeconds = 150.0
    /// `startCalliopeDiscovery` self-stops after ~20 s; re-arm the scan on this
    /// cadence while we wait for the mini to (re)appear.
    private static let flashReconnectScanRearmSeconds = 15.0
    private static let flashReconnectPollMs = 500

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        installConnectionObservers()
    }

    deinit {
        // Stop mirroring the host connection once the editor closes.
        for token in connectionObservers {
            NotificationCenter.default.removeObserver(token)
        }
        connectionObservers.removeAll()
        disconnectDebounceTimer?.cancel()
        disconnectDebounceTimer = nil
        flashReconnectTimer?.cancel()
        flashReconnectTimer = nil
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

        // Origin gate. The bridge grants firmware-flashing + raw GATT, and the
        // "calliope" script handler is attached to the whole web view — so any
        // frame the campus page navigates or embeds could otherwise reach it.
        // Gate on the SENDER frame's security origin (scheme + host): this is
        // stricter than Android's top-document-URL check (it also rejects a
        // hostile sub-frame on a campus page) and immune to navigation races.
        // Mirror Android's refusal — log and reject this request id rather than
        // drop silently, so the widget's promise rejects with a clear reason.
        let origin = message.frameInfo.securityOrigin
        let scheme = origin.`protocol`
        guard CampusUrls.isAllowed(scheme: scheme, host: origin.host) else {
            LogNotify.log("[ProxyBridge] dispatch refused — origin not in campus allowlist: \(scheme)://\(origin.host)")
            replyError(id: id, message: "bridge unavailable for this origin")
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
        // Cancel any prior connect-poll — a single in-flight attempt is enough.
        cancelConnectPoll()

        if let cal = activeCalliope() {
            // Happy path: device already paired via the legacy connection UI.
            // Skip the "connecting" blip — we're already there.
            cancelDisconnectDebounce()
            emitConnected(cal)
            enableSerialNotify(cal)
            replyOk(id: id)
            return
        }

        emitState(status: "connecting")

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
            "text": NSLocalizedString("Please select and connect a Calliope mini using the Calliope icon at the top.", comment: "Proxy bridge: connect requested but no device paired yet"),
        ])
        scheduleConnectPoll(remaining: Self.connectPollSeconds)
    }

    private func scheduleConnectPoll(remaining: Int) {
        guard remaining > 0 else {
            let id = pendingConnectReplyId
            pendingConnectReplyId = nil
            emitState(status: "error", errorMessage: NSLocalizedString("No Calliope mini paired", comment: "Proxy bridge: connect timed out, no device paired"))
            if let id = id {
                replyError(id: id, message: NSLocalizedString("No Calliope mini paired — please pair one via the connection icon at the top of the app and try again.", comment: "Proxy bridge: connect timed out, no device paired"))
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
                self.cancelDisconnectDebounce()
                self.emitConnected(cal)
                self.enableSerialNotify(cal)
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
        // "connected" later, and any pending disconnect-debounce so the
        // observer doesn't double-emit.
        cancelConnectPoll()
        cancelDisconnectDebounce()
        cancelFlashReconnect()
        bridgeConnected = false
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

    // MARK: - Host connection mirroring

    /// Observe the host app's BLE connection lifecycle and mirror it into the
    /// widget. The app — not the proxy — owns the radio, so the campus must
    /// reflect whatever the app reports: green the moment a calliope is usage-
    /// ready, red when the app gives up. Brief reboot/retry churn (notably the
    /// post-flash reboot) is suppressed by a debounce so the dot doesn't flicker.
    private func installConnectionObservers() {
        let center = NotificationCenter.default
        connectionObservers.append(
            center.addObserver(forName: DiscoveredBLEDevice.usageReadyNotificationName,
                               object: nil, queue: .main) { [weak self] _ in
                self?.handleHostUsageReady()
            }
        )
        connectionObservers.append(
            center.addObserver(forName: DiscoveredBLEDevice.disconnectedNotificationName,
                               object: nil, queue: .main) { [weak self] _ in
                self?.handleHostDisconnected()
            }
        )
    }

    /// The app reached a usage-ready calliope — reflect `connected` and (re)arm
    /// serial on the (possibly fresh) peripheral. Cancels any pending disconnect.
    private func handleHostUsageReady() {
        cancelDisconnectDebounce()
        flashSettleDeadline = nil
        guard let cal = activeCalliope() else { return }
        // Re-arm serial even if we already consider ourselves connected: after a
        // reboot the peripheral object is new and the old notify handler is dead.
        enableSerialNotify(cal)
        if !bridgeConnected {
            emitConnected(cal)
        }
    }

    /// The app lost a usage-ready calliope. Don't reflect it immediately — a
    /// reboot (especially right after a flash) or a transient drop that the app
    /// auto-recovers shouldn't flicker the campus. Wait out a window; only emit
    /// `disconnected` if the app still has no usage-ready calliope by then.
    private func handleHostDisconnected() {
        guard bridgeConnected else { return }
        // While a flash is in flight the mini reboots as part of DFU — never
        // reflect that as a connection loss; flash completion drives state.
        if pendingFlashReplyId != nil { return }
        scheduleDisconnectDebounce()
    }

    private func scheduleDisconnectDebounce() {
        cancelDisconnectDebounce()
        var delay = Self.disconnectDebounceSeconds
        if let deadline = flashSettleDeadline {
            delay = max(delay, deadline.timeIntervalSinceNow)
        }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        disconnectDebounceTimer = timer
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.disconnectDebounceTimer = nil
            // Recovered in the meantime — nothing to reflect.
            if self.activeCalliope() != nil { return }
            guard self.bridgeConnected else { return }
            self.bridgeConnected = false
            self.subscribedCharacteristics.removeAll()
            self.emitState(status: "disconnected", deviceName: "")
        }
        timer.resume()
    }

    private func cancelDisconnectDebounce() {
        disconnectDebounceTimer?.cancel()
        disconnectDebounceTimer = nil
    }

    /// Emit the full `connected` state (device + version fields) and mark the
    /// bridge connected. Shared by `connect`, the connect-poll, and the
    /// usage-ready observer so they stay identical.
    private func emitConnected(_ cal: BLECalliope) {
        let name = cal.peripheral.name ?? ""
        let fname = friendlyName(from: name)
        let (bv, cv) = versionFields(cal)
        // Remember the mini so a later reconnect-before-flash can re-target it.
        if let fname = fname { lastFriendlyName = fname }
        emitState(
            status: "connected",
            deviceName: name,
            friendlyName: fname,
            boardVersion: bv,
            calliopeVersion: cv,
            bleCanFlash: true,
            bleCanCommunicate: true,
            bleHasPermission: true
        )
        bridgeConnected = true
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
    private static let uartTxUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    /// Auto-subscribe Nordic UART TX and forward each notification as a
    /// `serialData` event the widget's serial layer consumes — the inbound half
    /// of proxy serial. Best-effort: no-op when the program exposes no UART
    /// (e.g. MicroPython). Mirrors the gattSubscribe install order (raw handler
    /// before setNotify) so the first packet isn't dropped.
    private func enableSerialNotify(_ cal: BLECalliope) {
        guard let ch = findCharacteristic(on: cal.peripheral,
                                          service: Self.uartServiceUUID,
                                          characteristic: Self.uartTxUUID) else { return }
        cal.rawNotificationHandlers[ch.uuid] = { [weak self] data in
            self?.sendEvent(kind: "serialData", data: ["data": data.base64EncodedString()])
        }
        cal.setNotify(characteristic: ch, true) { _ in }
    }

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
        // Optional editor hint: does the program being flashed leave BLE on?
        // Omitted ⇒ unknown (optimistically try to reconnect first). `false` ⇒
        // the editor already knows BLE will be off (MicroPython / MakeCode with
        // the radio extension), so prompt for A+B+Reset sooner. Never blocks the
        // flash — recovery is reactive regardless of this hint.
        let programHasBle = args["programHasBle"] as? Bool

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

        let hexFile = HexFile(url: tmpURL, name: safeName, date: Date())

        // A flash request supersedes any pending "disconnected" reflection.
        cancelDisconnectDebounce()

        if let cal = activeCalliope() {
            // Live connection — flash straight away.
            proceedWithFlash(id: id, cal: cal, hexFile: hexFile, argForceFullDfu: argForceFullDfu)
            return
        }

        // No live connection. This is the common state after flashing a program
        // that turns BLE off (MicroPython, or MakeCode with the radio extension):
        // the mini reboots into a non-advertising program and the link goes
        // stale. Try to (re)open the connection before flashing, and prompt the
        // user to put the mini into Bluetooth mode (A+B+Reset) if it isn't
        // advertising.
        beginFlashReconnect(
            id: id,
            hexFile: hexFile,
            argForceFullDfu: argForceFullDfu,
            programHasBle: programHasBle
        )
    }

    /// Flash a live, usage-ready calliope. Drops our notify subscriptions so the
    /// partial-flash / DFU machinery doesn't fight for the radio, then runs the
    /// blocks-runtime probe and hands off to `beginFlash`. The pending-flash
    /// bookkeeping (`pendingFlashReplyId`, `inFlightFlasher`) is set HERE — never
    /// during a reconnect attempt — so `handleHostDisconnected` doesn't mistake
    /// pre-flash reconnect churn for a flash reboot.
    private func proceedWithFlash(id: String, cal: BLECalliope, hexFile: HexFile, argForceFullDfu: Bool) {
        for (_, ch) in subscribedCharacteristics {
            cal.rawNotificationHandlers.removeValue(forKey: ch.uuid)
            cal.peripheral.setNotifyValue(false, for: ch)
        }
        subscribedCharacteristics.removeAll()

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
                    "text": NSLocalizedString("Blocks runtime detected — using full flash instead of partial flash", comment: "Proxy bridge: blocks runtime forces full DFU"),
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

    // MARK: Reconnect-before-flash

    /// Begin a reconnect-before-flash attempt: announce "connecting", then poll
    /// (scanning + connecting to the known mini, prompting for A+B+Reset) until
    /// a usage-ready calliope appears or we time out.
    private func beginFlashReconnect(id: String, hexFile: HexFile, argForceFullDfu: Bool, programHasBle: Bool?) {
        cancelFlashReconnect()
        emitState(status: "connecting")
        sendEvent(kind: "log", data: [
            "direction": "info",
            "text": NSLocalizedString("Reconnecting to your Calliope mini before flashing …", comment: "Proxy bridge: reopening a stale connection before a flash"),
        ])
        flashReconnectTick(
            id: id,
            hexFile: hexFile,
            argForceFullDfu: argForceFullDfu,
            programHasBle: programHasBle,
            elapsedMs: 0,
            promptShown: false,
            lastScanRearmMs: 0
        )
    }

    /// One step of the reconnect-before-flash loop. Runs immediately, then
    /// reschedules itself every `flashReconnectPollMs` until it flashes, times
    /// out, or is cancelled.
    private func flashReconnectTick(id: String, hexFile: HexFile, argForceFullDfu: Bool, programHasBle: Bool?, elapsedMs: Int, promptShown: Bool, lastScanRearmMs: Int) {
        // Success: a usage-ready calliope is available — flash it.
        if let cal = activeCalliope() {
            cancelFlashReconnect()
            // Reflect the recovered connection before we tear it down to flash.
            cancelDisconnectDebounce()
            emitConnected(cal)
            proceedWithFlash(id: id, cal: cal, hexFile: hexFile, argForceFullDfu: argForceFullDfu)
            return
        }

        // Gave up: the mini never (re)appeared in Bluetooth mode.
        if elapsedMs >= Int(Self.flashReconnectMaxSeconds * 1000) {
            cancelFlashReconnect()
            emitState(status: "disconnected", deviceName: "")
            replyError(id: id, message: NSLocalizedString("Couldn't reach your Calliope mini. Hold A+B and press reset on the mini to turn Bluetooth back on, then try flashing again.", comment: "Proxy bridge: reconnect-before-flash timed out"))
            return
        }

        // (Re)arm discovery — `startCalliopeDiscovery` self-stops after ~20 s.
        var scanRearm = lastScanRearmMs
        if elapsedMs == 0 || elapsedMs - lastScanRearmMs >= Int(Self.flashReconnectScanRearmSeconds * 1000) {
            MatrixConnectionViewController.instance?.moveToForeground()
            scanRearm = elapsedMs
        }

        // If the target mini is visible and idle, connect to it. The connect is
        // async; a later tick sees `activeCalliope()` once it reaches usageReady.
        if let connector = MatrixConnectionViewController.instance?.connector,
           connector.state != .connecting,
           let target = flashReconnectTarget(in: connector),
           target.state == .discovered {
            connector.connectToCalliope(target)
        }

        // Surface the A+B+Reset prompt once the optimistic window passes (or
        // immediately when the editor told us the program has no BLE).
        var shown = promptShown
        let promptAtMs = (programHasBle == false) ? 0 : Int(Self.flashReconnectOptimisticSeconds * 1000)
        if !shown && elapsedMs >= promptAtMs {
            shown = true
            // New event kind: widgets that understand it open the BLE-offline
            // (A+B+Reset) modal; older widgets ignore it and fall back to the
            // log line below.
            sendEvent(kind: "bleModeRequest", data: ["reason": "no-mini-visible"])
            sendEvent(kind: "log", data: [
                "direction": "info",
                "text": NSLocalizedString("Your Calliope mini isn't in Bluetooth mode. Hold A+B and press reset on the mini — it will then flash automatically.", comment: "Proxy bridge: ask user to enter BLE mode before flashing"),
            ])
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        flashReconnectTimer = timer
        timer.schedule(deadline: .now() + .milliseconds(Self.flashReconnectPollMs))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.flashReconnectTimer = nil
            self.flashReconnectTick(
                id: id,
                hexFile: hexFile,
                argForceFullDfu: argForceFullDfu,
                programHasBle: programHasBle,
                elapsedMs: elapsedMs + Self.flashReconnectPollMs,
                promptShown: shown,
                lastScanRearmMs: scanRearm
            )
        }
        timer.resume()
    }

    /// The mini to reconnect to before flashing: the one we last connected to
    /// (by friendly name), else the single visible BLE mini if unambiguous.
    private func flashReconnectTarget(in connector: CalliopeDiscovery) -> DiscoveredDevice? {
        if let key = lastFriendlyName, let dev = connector.discoveredCalliopes[key] {
            return dev
        }
        let bleDevices = connector.discoveredCalliopes.values.filter { $0 is DiscoveredBLEDevice }
        return bleDevices.count == 1 ? bleDevices.first : nil
    }

    private func cancelFlashReconnect() {
        flashReconnectTimer?.cancel()
        flashReconnectTimer = nil
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
    /// with `true` if the device is running pxt-blocks-runtime. Mirrors the
    /// widget's `program-type.ts probeBle` heuristic.
    ///
    /// The implementation lives on `BLECalliope` so the legacy
    /// download-capture path (`FirmwareUpload`) applies the exact same
    /// detection — see `BLECalliope.probeBlocksRuntime`.
    private func probeBlocksRuntime(on cal: BLECalliope, onResult: @escaping (Bool) -> Void) {
        cal.probeBlocksRuntime(completion: onResult)
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
        friendlyName: String? = nil,
        boardVersion: String? = nil,
        calliopeVersion: String? = nil,
        bleCanFlash: Bool? = nil,
        bleCanCommunicate: Bool? = nil,
        bleHasPermission: Bool? = nil
    ) {
        var d: [String: Any] = ["transport": "ble", "status": status]
        if let deviceName = deviceName { d["deviceName"] = deviceName }
        if let errorMessage = errorMessage { d["errorMessage"] = errorMessage }
        if let friendlyName = friendlyName { d["friendlyName"] = friendlyName }
        if let boardVersion = boardVersion { d["boardVersion"] = boardVersion }
        if let calliopeVersion = calliopeVersion { d["calliopeVersion"] = calliopeVersion }
        if let bleCanFlash = bleCanFlash { d["bleCanFlash"] = bleCanFlash }
        if let bleCanCommunicate = bleCanCommunicate { d["bleCanCommunicate"] = bleCanCommunicate }
        if let bleHasPermission = bleHasPermission { d["bleHasPermission"] = bleHasPermission }
        sendEvent(kind: "state", data: d)
    }

    /// Map the connected calliope's concrete type to the widget's version
    /// strings (boardVersion, calliopeVersion), so the web layer doesn't guess.
    /// CalliopeV3 = V2-class silicon (Mini 3 == micro:bit v2); CalliopeV1AndV2 =
    /// V1-class (Mini 1 & 2). `Any?` so we don't depend on the base type name.
    private func versionFields(_ cal: Any?) -> (String?, String?) {
        if cal is CalliopeV3 { return ("V2", "V3") }
        if cal is CalliopeV1AndV2 { return ("V1", "V1") }
        return (nil, nil)
    }

    /// Pull the 5-letter CVCVC friendly name out of an advertised name like
    /// "Calliope mini [zuvav]". Nil if absent.
    private func friendlyName(from name: String?) -> String? {
        guard let name = name,
              let r = name.range(of: "[zvgpt][uoiea][zvgpt][uoiea][zvgpt]",
                                 options: [.regularExpression, .caseInsensitive])
        else { return nil }
        return String(name[r]).lowercased()
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
        // The mini reboots into the freshly-flashed program now; reconnect +
        // service discovery takes a few seconds. Hold off reflecting a
        // disconnect for the settle window so a healthy reboot doesn't flicker
        // the campus — but if the new program has no BLE and never comes back,
        // the debounce still fires and we go red after the window.
        flashSettleDeadline = Date(timeIntervalSinceNow: Self.flashSettleSeconds)
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

// MARK: - Origin allowlist

/// Swift port of the Android `CampusUrls` allowlist — the single source of
/// truth for which web origins may drive the native-proxy bridge. The bridge
/// is only attached to `CampusEditor` web views, but that is a registration-
/// time gate; this is the per-message runtime gate that keeps the firmware-
/// flash / raw-GATT capability from leaking to any other origin the campus
/// page might navigate or link out to.
///
/// Matched hosts (https only):
///   - campus.calliope.cc          and any *.campus.calliope.cc
///   - calliope-campus.pages.dev   and any *.calliope-campus.pages.dev
///     (covers the Cloudflare Pages preview, e.g.
///      rc11.calliope-campus.pages.dev)
///
/// Suffix matching is anchored on a leading dot, so "evilcampus.calliope.cc"
/// and "campus.calliope.cc.attacker.com" do NOT match.
private enum CampusUrls {

    static let allowedHosts = [
        "campus.calliope.cc",
        "calliope-campus.pages.dev",
    ]

    /// Mirrors Android `CampusUrls.isCampusUrl`, but split so it can gate a
    /// `WKSecurityOrigin` (scheme + host) directly without rebuilding a URL.
    static func isAllowed(scheme: String?, host: String?) -> Bool {
        guard let scheme = scheme, scheme.lowercased() == "https" else { return false }
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return allowedHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    /// Convenience for gating a full URL (e.g. the configured campus URL).
    static func isCampusUrl(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        return isAllowed(scheme: url.scheme, host: url.host)
    }
}
