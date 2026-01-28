//
//  BluetoothConstants.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 23.02.19.
//
//  IMPROVED VERSION: Better timing for DFU reconnect

import Foundation

struct BluetoothConstants {
    static let discoveryTimeout = 20.0
    static let connectTimeout = 5
    static let serviceDiscoveryTimeout = 10.0
    static let readTimeout = 10.0
    static let writeTimeout = 10.0
    static let startDfuProcessDelay = 2.0

    static let maxRetryCount = 5
    static let retryDelay = 5

    //set this to 0 if coupling is not necessary
    static let couplingDelay = 0.0
    
    //this should be a little longer than the duration (in seconds)
    //that the calliope needs for restarting in program 5
    static let restartDuration = 2.0
    
    // NEU: Längere Wartezeit nach DFU Flash
    // Der Calliope V3 braucht mehr Zeit zum Neustarten nach Firmware-Update
    static let dfuRestartDuration = 4.0
    
    // NEU: Maximale Anzahl Reconnect-Versuche nach DFU
    static let maxDFUReconnectAttempts = 5
    
    // NEU: Zeit zwischen DFU Reconnect-Versuchen
    static let dfuReconnectInterval = 3.0

    static let lastConnectedKey = "cc.calliope.latestDeviceKey"
    static let lastConnectedNameKey = "name"
    static let lastConnectedUUIDKey = "uuidString"
    static let deviceNames = ["calliope", "micro:bit"]
}
