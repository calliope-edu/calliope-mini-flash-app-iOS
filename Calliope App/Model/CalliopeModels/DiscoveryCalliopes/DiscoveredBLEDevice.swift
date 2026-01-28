//
//  CalliopeBLEDevice.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 08.12.18.
//

import CoreBluetooth
import UIKit

class DiscoveredBLEDDevice: DiscoveredDevice {

    public static let usageReadyNotificationName = NSNotification.Name("calliope_is_usage_ready")
    public static let disconnectedNotificationName = NSNotification.Name("calliope_connection_lost")

    private let bluetoothQueue = DispatchQueue.global(qos: .userInitiated)

    let peripheral: CBPeripheral

    var serviceToDiscoveredCharacteristicsMap = [CBUUID: Set<CBUUID>]()


    lazy var servicesWithUndiscoveredCharacteristics: Set<CBUUID> = {
        return discoveredServicesUUIDs
    }()

    required init(peripheral: CBPeripheral, name: String) {
        self.peripheral = peripheral
        super.init(name: name)
        peripheral.delegate = self

    }

    public func shouldReconnectAfterReboot() -> Bool {
        return usageReadyCalliope?.shouldRebootOnDisconnect ?? false
    }


    // MARK: Services discovery

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        guard error == nil else {

            LogNotify.log("Error discovering services \(error!)")

            LogNotify.log(error!.localizedDescription)
            state = .wrongMode
            return
        }

        let services = peripheral.services ?? []
        let uuidSet = Set(
            services.map {
                return $0.uuid
            })

        LogNotify.log("Did discover services \(services)")

        let discoveredServiceUUIDs = uuidSet
        discoveredServices = Set(
            discoveredServiceUUIDs.compactMap {
                CalliopeBLEProfile.uuidServiceMap[$0]
            })
        services
            .forEach { service in
                peripheral.discoverCharacteristics(
                    CalliopeBLEProfile.serviceCharacteristicUUIDMap[service.uuid], for: service)
            }

        //Discovered All Services, Flashablecalliope with correct Version can now be created
    }

    // MARK: Characteristics discovery

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        guard error == nil else {
            LogNotify.log("Error discovering characteristics \(error!)")
            LogNotify.log(error!.localizedDescription)
            state = .wrongMode
            return
        }

        let characteristics = service.characteristics ?? []
        let uuidSet = Set(
            characteristics.map {
                return $0.uuid
            })
        serviceToDiscoveredCharacteristicsMap[service.uuid] = uuidSet

        LogNotify.log("Did discover characteristics \(uuidSet)")

        // Only continue once every discovered service has at least been checked for characteristics
        servicesWithUndiscoveredCharacteristics.remove(service.uuid)

        if servicesWithUndiscoveredCharacteristics.isEmpty {

            LogNotify.log("Did discover characteristics for all discovered services")

            // 1. Versuche zuerst einen flashbaren Calliope zu finden (V1/V2 oder V3 im DFU Mode)
            if let validBLECalliope = FlashableCalliopeFactory.getFlashableCalliopeForBLEDevice(device: self) {
                
                if let rebootingCalliope = rebootingCalliope, type(of: rebootingCalliope) === type(of: validBLECalliope) {
                    LogNotify.log("Choose rebooting calliope for use")
                    usageReadyCalliope = rebootingCalliope
                } else {
                    usageReadyCalliope = validBLECalliope
                }

                self.peripheral.delegate = usageReadyCalliope
                rebootingCalliope = nil
                state = .usageReady
                return
            }
            
            // 2. NEU: Fallback für Calliope V3 im Application Mode
            //    Prüfe ob dies ein V3 sein könnte (hat Partial Flashing Service aber kein DFU)
            if let connectedV3 = createConnectedCalliopeV3() {
                LogNotify.log("Created ConnectedCalliopeV3 - Calliope V3 is in Application Mode")
                
                // Wenn wir von einem DFU kommen, übernehme den alten Calliope-Zustand
                if let rebootingCalliope = rebootingCalliope as? ConnectedCalliopeV3 {
                    LogNotify.log("Preserving state from rebooting ConnectedCalliopeV3")
                    usageReadyCalliope = rebootingCalliope
                    self.peripheral.delegate = rebootingCalliope
                } else if let rebootingCalliope = rebootingCalliope as? CalliopeV3 {
                    // Wir hatten einen CalliopeV3 (DFU Mode) und sind jetzt im Application Mode
                    LogNotify.log("Transitioned from CalliopeV3 (DFU) to ConnectedCalliopeV3 (Application)")
                    usageReadyCalliope = connectedV3
                    self.peripheral.delegate = connectedV3
                } else {
                    // Frische Verbindung zu einem V3 im Application Mode
                    usageReadyCalliope = connectedV3
                    self.peripheral.delegate = connectedV3
                }
                
                rebootingCalliope = nil
                state = .usageReady
                return
            }
            
            // 3. Weder DFU-fähig noch V3 Application Mode - falscher Modus
            LogNotify.log("Could not create any Calliope type - wrong mode")
            state = .wrongMode
        }
    }
    
    // Versucht einen ConnectedCalliopeV3 zu erstellen (für V3 im Application Mode)
    // - Returns: ConnectedCalliopeV3 wenn die Bedingungen erfüllt sind, sonst nil
    private func createConnectedCalliopeV3() -> ConnectedCalliopeV3? {
        // Ein V3 im Application Mode hat typischerweise:
        // - Partial Flashing Service (zum Wechseln in DFU Mode)
        // - KEINEN Secure DFU Service (der ist nur im DFU Mode verfügbar)
        
        // Prüfe ob Partial Flashing verfügbar ist
        let hasPartialFlashing = discoveredServices.contains(.partialFlashing)
        
        // Prüfe ob KEIN DFU Service vorhanden ist (sonst wären wir im DFU Mode)
        let hasSecureDFU = discoveredServices.contains(.secureDfuService)
        let hasLegacyDFU = discoveredServices.contains(.dfuControlService)
        
        // V3 Application Mode: Hat Partial Flashing, aber kein DFU
        // ODER: Hat gar keine DFU Services (könnte auch V3 sein)
        if hasPartialFlashing && !hasSecureDFU && !hasLegacyDFU {
            LogNotify.log("Detected Calliope V3 in Application Mode (has Partial Flashing, no DFU)")
            return ConnectedCalliopeV3(
                peripheral: peripheral,
                name: name,
                discoveredServices: discoveredServices,
                discoveredCharacteristicUUIDsForServiceUUID: serviceToDiscoveredCharacteristicsMap,
                servicesChangedCallback: { [weak self] in self?.evaluateMode() }
            )
        }
        
        // Wenn wir von einem Reboot kommen (rebootingCalliope existiert) und es war ein V3
        if rebootingCalliope is CalliopeV3 || rebootingCalliope is ConnectedCalliopeV3 {
            LogNotify.log("Creating ConnectedCalliopeV3 as continuation of previous V3 session")
            return ConnectedCalliopeV3(
                peripheral: peripheral,
                name: name,
                discoveredServices: discoveredServices,
                discoveredCharacteristicUUIDsForServiceUUID: serviceToDiscoveredCharacteristicsMap,
                servicesChangedCallback: { [weak self] in self?.evaluateMode() }
            )
        }
        
        return nil
    }

    internal override func handleStateUpdate(_ oldState: DiscoveredDevice.CalliopeBLEDeviceState) {
        super.handleStateUpdate(oldState)
        if state == .evaluateMode {
            peripheral.delegate = self
        }
    }

    override func evaluateMode() {
        if let usageReadyCalliope = usageReadyCalliope, usageReadyCalliope.rebootingIntoDFUMode {
            LogNotify.log("Calliope is Rebooting For Firmwareupgrade, do not evaluate mode")
        } else if let rebootingCalliope = rebootingCalliope, rebootingCalliope.rebootingIntoDFUMode {
            LogNotify.log("RebootingCalliope exists do not evaluate mode")
        } else {
            LogNotify.log("Evaluating mode of calliope")
            //service discovery
            state = .evaluateMode
            peripheral.discoverServices([] + Self.discoverableServicesUUIDs)
        }
    }
}

//MARK: Equatable (conformance inherited default implementation by NSObject)

extension DiscoveredBLEDDevice {
    /*static func == (lhs: CalliopeBLEDevice, rhs: CalliopeBLEDevice) -> Bool {
     return lhs.peripheral == rhs.peripheral
     }*/

    override func isEqual(_ object: Any?) -> Bool {
        return self.peripheral == (object as? DiscoveredBLEDDevice)?.peripheral
    }
}

//MARK: CustomStringConvertible (conformance inherited default implementation by NSObject)

extension DiscoveredBLEDDevice {
    override var description: String {
        return "name: \(String(describing: name)), state: \(state)"
    }
}
