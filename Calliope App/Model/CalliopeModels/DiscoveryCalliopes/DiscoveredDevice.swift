//
//  DiscoveredDevice.swift
//  Calliope App
//
//  Created by itestra on 01.02.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import CoreBluetooth

class DiscoveredDevice: NSObject, CBPeripheralDelegate {
    
    private let bluetoothQueue = DispatchQueue.global(qos: .userInitiated)
    
    var updateQueue = DispatchQueue.main
    var updateBlock: () -> () = {}
    var errorBlock: (Error) -> () = { _ in }
    
    let name : String
    
    var usageReadyCalliope: Calliope?
    
    var rebootingCalliope: Calliope? = nil
    
    //discoverable Services of the BLE Devices
    static var discoverableServices: Set<CalliopeService> = [.secureDfuService, .dfuControlService, .partialFlashing, .accelerometer, .led, .temperature, .uart]
    static var discoverableServicesUUIDs: Set<CBUUID> = Set(discoverableServices.map { $0.uuid })
    
    //discovered Services of the BLE Device
    final var discoveredServices: Set<CalliopeService> = []
    lazy var discoveredServicesUUIDs: Set<CBUUID> = Set(discoveredServices.map { $0.uuid })
    
    enum CalliopeBLEDeviceState {
        case discovered //discovered and ready to connect, not connected yet
        case connected //connected, but services and characteristics have not (yet) been found
        case evaluateMode //connected, looking for services and characteristics
        case usageReady //all required services and characteristics have been found, calliope ready to be programmed
        case wrongMode //required services and characteristics not available, put into right mode
    }

    var state : CalliopeBLEDeviceState = .discovered {
        didSet {
            LogNotify.log("calliope state: \(state)")
            handleStateUpdate(oldValue)
            if usageReadyCalliope != nil {
                usageReadyCalliope?.notify(aboutState: state)
            }
        }
    }
    
    init(name: String) {
        self.name = name
        super.init()
    }
    
    internal func handleStateUpdate(_ oldState: CalliopeBLEDeviceState) {
        updateQueue.async { self.updateBlock() }
        if state == .discovered {
            discoveredServices = []
            if oldState == .usageReady {
                NotificationCenter.default.post(name: DiscoveredBLEDDevice.disconnectedNotificationName, object: self)
            }
        } else if state == .connected {
            //immediately evaluate whether in playground mode
            updateQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.couplingDelay) {
                self.evaluateMode()
            }
        } else if state == .evaluateMode {
            self.bluetoothQueue.asyncAfter(deadline: DispatchTime.now() + BluetoothConstants.serviceDiscoveryTimeout) {
                //has not discovered all services in time, probably stuck
                if self.state == .evaluateMode {
                    self.updateQueue.async { self.errorBlock(NSLocalizedString("Service discovery on calliope has timed out!", comment: "")) }
                    self.state = .wrongMode
                }
            }
        } else if state == .usageReady {
            NotificationCenter.default.post(name: DiscoveredBLEDDevice.usageReadyNotificationName,
                                            object: self)
        }
    }
    
    /// evaluate whether calliope is in correct mode
    public func evaluateMode() {
        if let usageReadyCalliope = usageReadyCalliope, usageReadyCalliope.rebootingIntoDFUMode {
            LogNotify.log("Calliope is Rebooting For Firmwareupgrade, do not evaluate mode")
        } else if let rebootingCalliope = rebootingCalliope, rebootingCalliope.rebootingIntoDFUMode {
            LogNotify.log("RebootingCalliope exists do not evaluate mode")
        } else if self is DiscoveredUSBDevice {
            LogNotify.log("Calliope is USB Calliope, do not evaluate mode")
        } else {
            LogNotify.log("Evaluating mode of calliope")
            //service discovery
            state = .evaluateMode
        }
    }
    
    public func hasConnected() {
        if state == .discovered {
            state = .connected
        }
    }
    
    public func hasDisconnected() {
        if state != .discovered {
            state = .discovered
        }
    }
}
