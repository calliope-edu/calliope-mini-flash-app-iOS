import Foundation
import CoreBluetooth
import WebKit
import Dispatch

open class WBMessageHandler: NSObject, WKScriptMessageHandler
{
    
    // MARK: - Embedded types
    enum ManagerRequests: String {
        case device, requestDevice, getAvailability
    }
    
    // MARK: - WKScriptMessageHandler
    open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let trans = WBTransaction(withMessage: message) else {
            /* The transaction will have handled the error */
            return
        }
        
        self.triageManagerRequests(transaction: trans)
    }
    
    // MARK: - Private
    private func triageManagerRequests(transaction: WBTransaction){
        
        guard
            transaction.key.typeComponents.count > 0,
            let managerMessageType = ManagerRequests(
                rawValue: transaction.key.typeComponents[0])
        else {
            transaction.resolveAsFailure(withMessage: "Request type components not recognised \(transaction.key)")
            return
        }
        
        switch managerMessageType
        {
        case .device:
            if let connectedCalliope = MatrixConnectionViewController.instance.usageReadyCalliope {
                if(connectedCalliope is BLECalliope) {
                    (connectedCalliope as! BLECalliope).triage(transaction: transaction)
                }
                else {
                    print("Somehow you connected to a Calliope without bluetooth")
                }
            }
            print("Device specific Request!!!")
        case .getAvailability:
            // TODO: Find a better measure of wether bluetooth is enabled
            let bluetoothEnabled = MatrixConnectionViewController.instance.connector.state != .initialized
            transaction.resolveAsSuccess(withObject: bluetoothEnabled)
            print("Getting Availability!!!")
        case .requestDevice:
            print("Requesting Devices!!!")
            let connectedCalliope = MatrixConnectionViewController.instance.usageReadyCalliope
            if(connectedCalliope != nil && connectedCalliope is BLECalliope) {
                transaction.resolveAsSuccess(withObject: connectedCalliope! as! BLECalliope)
                print("Got BLE Calliope")
            }
        }
    }
    
    /*func triageDeviceRequests(transaction: WBTransaction) {
        let tc = transaction.key.typeComponents
        guard
            tc.count > 1,
            let deviceMessageType = DeviceRequests(rawValue: tc[1])
        else {
            transaction.resolveAsFailure(withMessage: "Unknown request type \(tc.joined(separator: ":"))")
            return
        }

        switch deviceMessageType {
        case .connectGATT:
            print("Webview tries to connect to GATT")
            transaction.resolveAsSuccess();
            
            
            
            
        case .disconnectGATT:
            print("Webview tries to connect to GATT")
            // TODO: Handle disconnect if that is the goal
            transaction.resolveAsSuccess();
            
        case .getPrimaryServices:
            let serviceUUID: CBUUID?
            if let pservStr = transaction.messageData["serviceUUID"] as? String {
                guard let pservUUID = UUID(uuidString: pservStr) else {
                    return
                }
                serviceUUID = CBUUID(nsuuid: pservUUID)
            } else {
                serviceUUID = nil
            }
            
            // TODO: Implement service discovery
            // This line below throws an false usage of the api error
            // self.peripheral.discoverServices(nil)
            guard let services = self.peripheral.services else {
                transaction.resolveAsFailure(withMessage: "Could not get services")
                return
            }
            
            let uuids = services.map{$0.uuid}.filter{
                serviceUUID == nil || serviceUUID == $0
            }
            if uuids.count > 0 {
                print(uuids[0])
                transaction.resolveAsSuccess(withObject: uuids)
            } else {
                transaction.resolveAsFailure(withMessage: serviceUUID != nil ? "Service \(serviceUUID!.uuidString) not known on device" : "No services found")
            }

        case .getCharacteristic:
            print("Trying to get a characteristic")
            transaction.resolveAsSuccess()

        case .getCharacteristics:
            print("Trying to get characteristics")
            /*guard let view = CharacteristicsView(transaction: transaction)
            else {
                transaction.resolveAsFailure(withMessage: "Invalid getCharacteristics message")
                break
            }

            guard let service = self.getService(withUUID: view.serviceUUID)
            else {
                view.resolveUnknownService()
                return
            }

            if let chars = service.characteristics {
                self.getCharacteristicsTM.apply({
                    var characteristicUUIDs: [String] = []
                    chars.forEach({ (characteristic) in
                        characteristicUUIDs.append(characteristic.uuid.uuidString)
                    })
                    $0.resolveAsSuccess(withObject: characteristicUUIDs)
                })
                
                break
            }

            self.getCharacteristicsTM.addTransaction(transaction, atPath: CharacteristicsTransactionKey(serviceUUID: view.serviceUUID))
            NSLog("Start discovering characteristics for service \(service.uuid)")
            self.peripheral.discoverCharacteristics(nil, for: service)*/

        case .readCharacteristicValue:
            print("Trying to read characteristic value")
            /*guard
                let view = CharacteristicView(transaction: transaction)
            else {
                transaction.resolveAsFailure(withMessage: "Invalid message")
                break
            }
            guard let service = self.getService(withUUID: view.serviceUUID) else {
                view.resolveUnknownService()
                break
            }
            guard let chars = service.characteristics else {
                transaction.resolveAsFailure(withMessage: "Characteristics have not yet been retrieved for service \(service.uuid.uuidString)")
                break
            }
            guard let char = chars.first(where: {$0.uuid == view.characteristicUUID}) else {
                view.resolveUnknownCharacteristic()
                break
            }

            self.readCharacteristicTM.addTransaction(transaction, atPath: CharacteristicTransactionKey(serviceUUID: view.serviceUUID, characteristicUUID: view.characteristicUUID))
            self.peripheral.readValue(for: char)*/

        case .writeCharacteristicValue:
            print("Trying to write a characteristic value")
            /*guard
                let view = WriteCharacteristicView(transaction: transaction)
            else {
                transaction.resolveAsFailure(withMessage: "Invalid write characteristic message")
                break
            }

            guard
                let char = self.getCharacteristic(view.serviceUUID, uuid: view.characteristicUUID)
            else {
                view.resolveUnknownCharacteristic()
                break
            }

            self.writeCharacteristicValue(char, view)*/

        case .startNotifications:
            print("Trying to start notifications")
            
            guard let view = CharacteristicTransaction(transaction: transaction) else {
                transaction.resolveAsFailure(withMessage: "Invalid start notifications message")
                break
            }

            guard let char = self.getCharacteristic(view.serviceUUID!, uuid: view.characteristicUUID) else {
                view.resolveUnknownCharacteristic()
                break
            }
            NSLog("Starting notifications for characteristic \(view.characteristicUUID.uuidString) on device \(self.peripheral.name ?? "<no-name>")")

            self.peripheral.setNotifyValue(true, for: char)
            transaction.resolveAsSuccess()

        case .stopNotifications:
            print("Trying to stop notification")
            /*guard let view = CharacteristicView(transaction: transaction) else {
                transaction.resolveAsFailure(withMessage: "Invalid start notifications message")
                break
            }

            guard let char = self.getCharacteristic(view.serviceUUID, uuid: view.characteristicUUID) else {
                view.resolveUnknownCharacteristic()
                break
            }
            NSLog("Stopping notifications for characteristic \(view.characteristicUUID.uuidString) on device \(self.peripheral.name ?? "<no-name>")")

            self.peripheral.setNotifyValue(false, for: char)
            transaction.resolveAsSuccess()*/
        }
    }*/
}
