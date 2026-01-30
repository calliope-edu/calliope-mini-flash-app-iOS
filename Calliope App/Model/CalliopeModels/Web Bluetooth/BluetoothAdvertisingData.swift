//
//  BluetoothAdvertisingData.swift
//  Calliope App
//
//  Created by Calliope on 30.01.26.
//  Copyright © 2026 calliope. All rights reserved.
//


/*!
 *  @class BluetoothAdvertisingData
 *
 *  @discussion This encapsulates the data required for a BluetoothAdvertisingEvent as per https://webbluetoothcg.github.io/web-bluetooth/#advertising-events .
 */

import Foundation
import CoreBluetooth

class BluetoothAdvertisingData{
    var appearance:String
    var txPower:NSNumber
    var rssi: String
    var manufacturerData:String
    var serviceData:[String]
    
    init(advertisementData: [String: Any], RSSI: NSNumber){
        self.appearance = "fakeappearance"
        self.txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber ?? 0)
        self.rssi = String(describing: RSSI)
        let data = advertisementData[CBAdvertisementDataManufacturerDataKey]
        self.manufacturerData = ""
        if data != nil {
            if let dataString = NSString(data: data as! Data, encoding: String.Encoding.utf8.rawValue) as String? {
                self.manufacturerData = dataString
            } else {
                NSLog("Error parsing advertisement data: not a valid UTF-8 sequence, was \(data as! Data)")
            }
        }
        
        var uuids = [String]()
        if advertisementData["kCBAdvDataServiceUUIDs"] != nil {
            uuids = (advertisementData["kCBAdvDataServiceUUIDs"] as! [CBUUID]).map{$0.uuidString.lowercased()}
        }
        self.serviceData = uuids
    }
    
    func toDict()->[String:AnyObject]{
        let dict:[String:AnyObject] = [
            "appearance": self.appearance as AnyObject,
            "txPower": self.txPower,
            "rssi": self.rssi as AnyObject,
            "manufacturerData": self.manufacturerData as AnyObject,
            "serviceData": self.serviceData as AnyObject
        ]
        return dict
    }
}
