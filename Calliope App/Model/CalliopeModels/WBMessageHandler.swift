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
    
    enum DeviceRequests: String {
        case connectGATT, disconnectGATT, getPrimaryServices,
        getCharacteristic, getCharacteristics, readCharacteristicValue, startNotifications,
        stopNotifications,
        writeCharacteristicValue
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
            triageDeviceRequests(transaction: transaction)
        case .getAvailability:
            // TODO: Find a better measure of wether bluetooth is enabled
            let bluetoothEnabled = MatrixConnectionViewController.instance.connector.state != .initialized
            transaction.resolveAsSuccess(withObject: bluetoothEnabled)
        case .requestDevice:
            let connectedCalliope = MatrixConnectionViewController.instance.usageReadyCalliope
            if(connectedCalliope != nil && connectedCalliope is BLECalliope) {
                transaction.resolveAsSuccess(withObject: connectedCalliope! as! BLECalliope)
            }
        }
    }
    
    func triageDeviceRequests(transaction: WBTransaction) {
        let tc = transaction.key.typeComponents
        guard
            tc.count > 1,
            let deviceMessageType = DeviceRequests(rawValue: tc[1])
        else {
            transaction.resolveAsFailure(withMessage: "Unknown request type \(tc.joined(separator: ":"))")
            return
        }
        
        guard let calliope = MatrixConnectionViewController.instance.usageReadyCalliope as? BLECalliope else {
            print("Somehow you connected to a Calliope without bluetooth")
            return
        }

        switch deviceMessageType {
        case .connectGATT:
            print("Webview tries to connect to GATT")
            // already ensured that the app is connected to the calliope
            transaction.resolveAsSuccess();
            
        case .disconnectGATT:
            print("Webview tries to connect to GATT")
            // TODO: Handle disconnect if that is the goal
            transaction.resolveAsSuccess();
            
        case .getPrimaryServices:
            calliope.getPrimaryServices(transaction: transaction)

        case .getCharacteristic:
            calliope.getCharacteristic(transaction: transaction)

        case .getCharacteristics:
            calliope.getCharacteristics(transaction: transaction)

        case .readCharacteristicValue:
            calliope.readCharacteristicValue(transaction: transaction)

        case .writeCharacteristicValue:
            calliope.writeCharacteristicValue(transaction: transaction)

        case .startNotifications:
            calliope.startNotifications(transaction: transaction)

        case .stopNotifications:
            calliope.stopNotifications(transaction: transaction)
        }
    }
}
