//
//  PartialFlashingOptimized.swift
//  Calliope App
//
//  Optimierte Partial Flashing Implementierung mit Pipelining für Calliope V3
//
//  Problem der alten Implementierung:
//  - Sendet 4 Pakete, wartet auf Notification, sendet nächste 4 Pakete
//  - Bei ~20ms RTT pro Notification dauert das viel zu lange
//  - Connection Timeout bei ~60% der Übertragung
//
//  Lösung:
//  - Pipelining: Mehrere 4er-Blöcke "in flight" ohne auf jede Notification zu warten
//  - Sliding Window: Maximal N Blöcke gleichzeitig unterwegs
//  - Notification nur für Flow Control, nicht für jedes Paket
//

import Foundation
import CoreBluetooth

// MARK: - Pipelining Configuration Constants

struct PartialFlashingConfig {
    /// Maximale Anzahl von 4er-Blöcken die gleichzeitig "in flight" sein dürfen
    /// Basierend auf Android-Analyse: Start mit 1 Block, da Android auch nach jedem Block wartet
    /// Der Geschwindigkeitsgewinn kommt von schneller Paket-Übertragung INNERHALB des Blocks
    static let maxBlocksInFlight = 1  // Match Android: sequential blocks

    /// Verzögerung zwischen Paketen INNERHALB eines 4er-Blocks (in Sekunden)
    /// Android: 3-15ms zwischen Paketen (Thread.sleep(3), max 5 Iterationen)
    /// iOS: Nutzen wir writeWithoutResponse für maximale Geschwindigkeit (keine Verzögerung nötig)
    static let intraBlockPacketDelay: TimeInterval = 0.0  // No delay - let BLE stack handle it

    /// Timeout für Gesamtübertragung (in Sekunden)
    static let timeout: TimeInterval = 120.0  // 2 Minuten

    /// Aktiviert optimiertes Partial Flashing (für einfaches An/Aus)
    /// ENABLED - Testing Android-style rapid packet transmission
    static let enabled = true
}

// MARK: - Optimized Partial Flashing Manager

/// Separater Manager für optimiertes Partial Flashing
/// Kann als Ersatz für die bestehende Implementierung verwendet werden
class OptimizedPartialFlashingManager {
    
    // MARK: - State
    
    private weak var calliope: FlashableBLECalliope?
    private var allPackages: [(segmentAddress: UInt16, address: UInt16, data: Data)] = []
    private var nextPackageIndex: Int = 0
    private var acknowledgedBlockCount: Int = 0
    private var blocksInFlight: Int = 0
    private var startTime: Date?
    private(set) var isActive: Bool = false  // Von außen lesbar für Notification-Routing
    
    // Callbacks
    var progressCallback: ((Int, Int) -> Void)?  // (current, total)
    var completionCallback: ((Bool, String) -> Void)?  // (success, message)
    var logCallback: ((String) -> Void)?
    
    // MARK: - Protocol Constants
    
    private struct Command {
        static let REGION: UInt8 = 0x00
        static let WRITE: UInt8 = 0x01
        static let TRANSMISSION_END: UInt8 = 0x02
        static let STATUS: UInt8 = 0xEE
    }
    
    private struct Region {
        static let DAL: UInt8 = 0x00
        static let PROGRAM: UInt8 = 0x01
        static let EMBEDDED: UInt8 = 0x02
    }
    
    private struct WriteStatus {
        static let SUCCESS: UInt8 = 0xFF  // Korrigiert: 0xFF = Success
        static let FAIL: UInt8 = 0xAA     // Korrigiert: 0xAA = Fail
    }
    
    // MARK: - Initialization
    
    init(calliope: FlashableBLECalliope) {
        self.calliope = calliope
    }
    
    // MARK: - Public API
    
    /// Startet optimiertes Partial Flashing
    func start(with partialFlashData: PartialFlashData) {
        log("Starting optimized partial flashing with pipelining")
        
        startTime = Date()
        
        // Bereite Pakete im Hintergrund vor um UI nicht zu blockieren
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Bereite Pakete vor
            self.preparePackages(from: partialFlashData)
            
            guard !self.allPackages.isEmpty else {
                self.log("No packages to flash")
                DispatchQueue.main.async {
                    self.completionCallback?(false, "No packages to flash")
                }
                return
            }
            
            self.log("Prepared \(self.allPackages.count) packages for transmission")
            
            // Starte Pipeline auf Main Thread (BLE writes müssen dort passieren)
            DispatchQueue.main.async {
                // WICHTIG: isActive erst HIER setzen, damit Notifications erst ab jetzt geroutet werden
                self.isActive = true
                self.fillPipeline()
            }
        }
    }
    
    /// Verarbeitet eingehende Notification
    func handleNotification(_ value: Data) {
        guard isActive else { return }
        
        // Check Timeout
        if let start = startTime, Date().timeIntervalSince(start) > PartialFlashingConfig.timeout {
            log("Timeout after \(PartialFlashingConfig.timeout)s")
            fail(reason: "Timeout")
            return
        }
        
        guard value.count >= 2 else {
            log("Invalid notification: too short")
            return
        }
        
        // Nur WRITE Responses verarbeiten
        guard value[0] == Command.WRITE else {
            log("Ignoring non-WRITE notification: \(value.hexEncodedString())")
            return
        }
        
        switch value[1] {
        case WriteStatus.SUCCESS:
            handleWriteSuccess()
            
        case WriteStatus.FAIL:
            log("Received WRITE_FAIL")
            fail(reason: "Device reported write failure")
            
        default:
            log("Unknown write status: \(value[1])")
            fail(reason: "Unknown write status")
        }
    }
    
    /// Bricht die Übertragung ab
    func cancel() {
        log("Partial flashing cancelled")
        isActive = false
    }
    
    // MARK: - Private Methods
    
    private func preparePackages(from data: PartialFlashData) {
        allPackages = []
        nextPackageIndex = 0
        acknowledgedBlockCount = 0
        blocksInFlight = 0
        
        var mutableData = data
        
        // Wichtig: Die Segment-Adresse muss VOR dem next() Aufruf gelesen werden,
        // genau wie in der Original-Implementierung
        while true {
            // Lese aktuelle Segment-Adresse BEVOR next() aufgerufen wird
            let currentSegment = mutableData.currentSegmentAddress
            
            guard let package = mutableData.next() else { break }
            
            allPackages.append((
                segmentAddress: currentSegment,
                address: package.address,
                data: package.data
            ))
        }
    }
    
    private func fillPipeline() {
        // Sende Blöcke bis Pipeline voll oder keine Pakete mehr
        // WICHTIG: Kein Thread.sleep() hier - das würde den BLE-Callback-Thread blockieren!
        while blocksInFlight < PartialFlashingConfig.maxBlocksInFlight && hasMorePackages() {
            sendNextBlock()
        }
        
        // Prüfe ob bereits fertig (sehr kleine Dateien)
        checkCompletion()
    }
    
    private func hasMorePackages() -> Bool {
        return nextPackageIndex < allPackages.count
    }
    
    private func sendNextBlock() {
        guard let calliope = calliope else {
            fail(reason: "Calliope connection lost")
            return
        }
        
        let blockStart = nextPackageIndex
        var packagesInBlock: [(segmentAddress: UInt16, address: UInt16, data: Data)] = []
        
        // Sammle bis zu 4 Pakete
        for i in 0..<4 {
            let idx = blockStart + i
            guard idx < allPackages.count else { break }
            packagesInBlock.append(allPackages[idx])
        }
        
        guard !packagesInBlock.isEmpty else { return }
        
        // Die Segment-Adresse für diesen Block ist die des ERSTEN Pakets im Block
        // (so wie in der Original-Implementierung)
        let blockSegmentAddress = packagesInBlock[0].segmentAddress
        
        // Sende Pakete
        let startPacketNum = UInt8(truncatingIfNeeded: blockStart)
        
        for (i, pkg) in packagesInBlock.enumerated() {
            // Segment-Adresse NUR im zweiten Paket des Blocks (index == 1)
            // In allen anderen Paketen wird die normale Adresse verwendet
            let addr: UInt16 = (i == 1) ? blockSegmentAddress : pkg.address
            let packetNum = startPacketNum &+ UInt8(i)
            
            let writeData = addr.bigEndianData + Data([packetNum]) + pkg.data
            
            do {
                try calliope.writeWithoutResponse(Data([Command.WRITE]) + writeData, for: .partialFlashing)
            } catch {
                log("Write failed: \(error)")
                fail(reason: "BLE write failed")
                return
            }
        }
        
        // Update State
        nextPackageIndex += packagesInBlock.count
        blocksInFlight += 1
        
        // Progress Update
        reportProgress()
        
        // WICHTIG: Wenn der letzte Block weniger als 4 Pakete hat,
        // sende END sofort (wie in der Original-Implementierung)
        if packagesInBlock.count < 4 {
            log("Last block had \(packagesInBlock.count) packages - sending END")
            sendEndTransmission()
        }
    }
    
    private func sendEndTransmission() {
        guard isActive else { return }
        isActive = false

        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        log("Sending TRANSMISSION_END after \(String(format: "%.2f", duration))s")

        // WICHTIG: Setze isPartiallyFlashing SOFORT auf false VOR dem Senden von TRANSMISSION_END,
        // damit ein nachfolgender Disconnect nicht als Fehler gewertet wird
        // Der Calliope könnte sich sofort nach Empfang von TRANSMISSION_END trennen!
        calliope?.isPartiallyFlashing = false
        calliope?.shouldRebootOnDisconnect = false

        // Kleine Verzögerung um sicherzustellen, dass die Flags gesetzt sind
        // bevor der Calliope sich trennt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self, let calliope = self.calliope else { return }

            // Sende END Kommando
            do {
                try calliope.writeWithoutResponse(Data([Command.TRANSMISSION_END]), for: .partialFlashing)
                self.log("TRANSMISSION_END sent successfully")
            } catch {
                self.log("Failed to send TRANSMISSION_END: \(error)")
            }

            // Completion callback NACH dem Senden
            self.completionCallback?(true, "Completed in \(String(format: "%.2f", duration))s")
        }
    }
    
    private func handleWriteSuccess() {
        blocksInFlight = max(0, blocksInFlight - 1)
        acknowledgedBlockCount += 1
        
        // Nur alle 50 Blöcke loggen um System nicht zu überlasten
        if acknowledgedBlockCount % 50 == 0 {
            log("Block \(acknowledgedBlockCount) acknowledged, \(blocksInFlight) in flight, \(allPackages.count - nextPackageIndex) remaining")
        }
        
        // Fülle Pipeline nach
        if hasMorePackages() {
            fillPipeline()
        }
        
        checkCompletion()
    }
    
    private func checkCompletion() {
        // Wenn alle Pakete gesendet wurden und keine mehr in flight sind,
        // UND wir noch aktiv sind (d.h. END wurde noch nicht gesendet),
        // dann sende jetzt END
        if !hasMorePackages() && blocksInFlight == 0 && isActive {
            // Dies passiert wenn der letzte Block genau 4 Pakete hatte
            log("All blocks acknowledged - sending END")
            sendEndTransmission()
        }
    }
    
    private func finish() {
        // Diese Methode wird nicht mehr direkt verwendet
        // sendEndTransmission() übernimmt diese Aufgabe
        sendEndTransmission()
    }
    
    private func fail(reason: String) {
        guard isActive else { return }
        isActive = false
        
        log("Failed: \(reason)")
        completionCallback?(false, reason)
    }
    
    private func reportProgress() {
        let total = allPackages.count
        let done = nextPackageIndex
        progressCallback?(done, total)
    }
    
    private func log(_ message: String) {
        LogNotify.log("[OptimizedPF] \(message)")
        logCallback?(message)
    }
}

// MARK: - Helper Extensions

private extension UInt16 {
    var bigEndianData: Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: 2)
    }
}

private extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - Integration Guide

/*
 ══════════════════════════════════════════════════════════════════════════════
 INTEGRATION IN FlashableBLECalliope.swift
 ══════════════════════════════════════════════════════════════════════════════
 
 1. PROPERTY HINZUFÜGEN:
 
    private var optimizedFlashingManager: OptimizedPartialFlashingManager?
 
 2. IN receivedProgramHash() - ERSETZE den Partial Flashing Aufruf:
 
    private func receivedProgramHash() {
        if hexProgramHash != currentProgramHash {
            updateCallback("Program hash mismatch, need to flash")
            
            if PartialFlashingConfig.enabled {
                // Nutze optimiertes Partial Flashing
                startOptimizedPartialFlashingWithManager()
            } else {
                // Fallback auf alte Implementierung
                sendFlashData()
            }
        } else {
            updateCallback("Program hash matches, no flash needed")
            endTransmission()
            statusDelegate?.dfuStateDidChange(to: .completed)
        }
    }
 
 3. NEUE METHODE HINZUFÜGEN:
 
    private func startOptimizedPartialFlashingWithManager() {
        guard let partialFlashData = partialFlashData else {
            fallbackToFullFlash()
            return
        }
        
        let manager = OptimizedPartialFlashingManager(calliope: self)
        self.optimizedFlashingManager = manager
        
        manager.progressCallback = { [weak self] current, total in
            let percent = total > 0 ? Int((Double(current) / Double(total)) * 100) : 0
            self?.progressReceiver?.dfuProgressDidChange(
                for: 1, outOf: 1, to: percent,
                currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0
            )
        }
        
        manager.completionCallback = { [weak self] success, message in
            if success {
                self?.isPartiallyFlashing = false
                self?.shouldRebootOnDisconnect = false
                self?.statusDelegate?.dfuStateDidChange(to: .completed)
            } else {
                self?.fallbackToFullFlash()
            }
        }
        
        manager.logCallback = { [weak self] message in
            self?.logReceiver?.logWith(.info, message: message)
        }
        
        manager.start(with: partialFlashData)
    }
 
 4. IN handleValueUpdate() - NOTIFICATION ROUTING:
 
    override func handleValueUpdate(_ characteristic: CalliopeCharacteristic, _ value: Data) {
        guard characteristic == .partialFlashing else {
            super.handleValueUpdate(characteristic, value)
            return
        }
        
        updateQueue.async {
            // Prüfe ob optimierter Manager aktiv ist
            if let manager = self.optimizedFlashingManager {
                manager.handleNotification(value)
            } else {
                self.handlePartialValueNotification(value)
            }
        }
    }
 
 5. IN cancelUpload() - MANAGER CANCELN:
 
    func cancelUpload() -> Bool {
        optimizedFlashingManager?.cancel()
        optimizedFlashingManager = nil
        // ... rest of existing code
    }
 
 ══════════════════════════════════════════════════════════════════════════════
 FÜR CalliopeV3.swift - AKTIVIERUNG
 ══════════════════════════════════════════════════════════════════════════════
 
 In der startPartialFlashing() Methode:
 
 VORHER (deaktiviert):
    func startPartialFlashing() {
        // Partial Flashing für V3 deaktiviert wegen Performance-Problemen
        try? startFullFlashing()
    }
 
 NACHHER (aktiviert):
    func startPartialFlashing() {
        // Nutze optimiertes Partial Flashing
        super.startPartialFlashing()
    }
 
 ══════════════════════════════════════════════════════════════════════════════
 KONFIGURATION
 ══════════════════════════════════════════════════════════════════════════════
 
 In PartialFlashingConfig anpassen:
 
 - maxBlocksInFlight: Erhöhen für mehr Speed (4-8 empfohlen)
 - blockSendInterval: Verringern für mehr Speed (0.005-0.01s empfohlen)
 - timeout: Erhöhen wenn große Dateien geflasht werden
 - enabled: false zum Deaktivieren
 
 ══════════════════════════════════════════════════════════════════════════════
*/
