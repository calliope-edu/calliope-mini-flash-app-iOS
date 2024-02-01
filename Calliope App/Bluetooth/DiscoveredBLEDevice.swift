//
//  CalliopeBLEDevice.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 08.12.18.
//

import UIKit
import CoreBluetooth

class DiscoveredBLEDDevice: DiscoveredDevice {
    
    public static let usageReadyNotificationName = NSNotification.Name("calliope_is_usage_ready")
    public static let disconnectedNotificationName = NSNotification.Name("calliope_connection_lost")
    
    private let bluetoothQueue = DispatchQueue.global(qos: .userInitiated)
    
    let peripheral: CBPeripheral
    
    var serviceToDiscoveredCharacteristicsMap = [CBUUID : Set<CBUUID>]()
    
    
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
        let uuidSet = Set(services.map { return $0.uuid })
        
        LogNotify.log("Did discover services \(services)")
        
        let discoveredServiceUUIDs = uuidSet
        discoveredServices = Set(discoveredServiceUUIDs.compactMap { CalliopeBLEProfile.uuidServiceMap[$0] })
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
        let uuidSet = Set(characteristics.map { return $0.uuid })
        serviceToDiscoveredCharacteristicsMap[service.uuid] = uuidSet
        
        LogNotify.log("Did discover characteristics \(uuidSet)")
        
        //Only continue once every discovered service has atleast been checked for characteristic
        servicesWithUndiscoveredCharacteristics.remove(service.uuid)
        
        if(servicesWithUndiscoveredCharacteristics.isEmpty) {
            
            LogNotify.log("Did discover characteristics for all discovered services")
            
            guard let validBLECalliope = FlashableCalliopeFactory.getFlashableCalliopeForBLEDevice(device: self) else {
                state = .wrongMode
                return
            }
            
            if let rebootingCalliope = rebootingCalliope, type(of: rebootingCalliope) === type(of: validBLECalliope) {
                LogNotify.log("Choose rebooting calliope for use")
                // We saved a calliope in a reboot process, use that one
                usageReadyCalliope = rebootingCalliope
            } else {
                //new calliope found, delegate was set in initialization process
                usageReadyCalliope = validBLECalliope
            }
            
            self.peripheral.delegate = usageReadyCalliope
            
            rebootingCalliope = nil
            
            state = .usageReady
        }
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

