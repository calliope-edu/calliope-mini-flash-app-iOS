//
//  WBTransaction.swift
//  BleBrowser
//
//  Copyright 2016-2017 David Park. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import CoreBluetooth
import WebKit


class WBTransaction: Equatable, CustomStringConvertible {
    
    /*
     * ========== Embedded types ==========
     */
    struct Key: Hashable, CustomStringConvertible {
        let typeComponents: [String]
        
        func hash(into hasher: inout Hasher) {
            for tc in self.typeComponents {
                hasher.combine(tc)
            }
        }
        
        var description: String {
            let contents = self.typeComponents.reduce("") {
                (progress: String, next: String) in
                if (progress.isEmpty) {
                    return next
                } else {
                    return "\(progress):\(next)"
                }
            }
            return contents
        }
        
        static func == (left: Key, right: Key) -> Bool {
            guard left.typeComponents.count == right.typeComponents.count else {
                return false;
            }
            for (lstr, rstr) in zip(left.typeComponents, right.typeComponents) {
                if (lstr != rstr) {
                    return false
                }
            }
            return true
        }
    }
    class Wrapper {
        let transaction: WBTransaction
        
        /*! @abstract Failable initializer so that subclasses may decide not to accept the transaction. */
        init? (transaction: WBTransaction) {
            self.transaction = transaction
        }
    }
    
    /*
     * ========== Properties ==========
     */
    /*! @abstract The unique ID for this transaction which is provided for us by the web page */
    let id: Int
    let key: Key
    let messageData: [String: AnyObject]
    /*! @abstract The web view that initiated this transaction, and where we can send the response.
     */
    weak var webView: WBWebView?
    var completionHandlers = [(WBTransaction, Bool) -> Void]()
    var resolved: Bool = false
    
    /*
     * ========== Initializers ==========
     */
    init(id: Int, typeComponents: [String], messageData: [String: AnyObject], webView: WKWebView?){
        self.id = id
        self.key = Key(typeComponents: typeComponents)
        self.messageData = messageData
        self.webView = webView as? WBWebView
    }
    convenience init?(withMessage message: WKScriptMessage) {
        
        guard
            let messageBody = message.body as? NSDictionary,
            let id = messageBody["callbackID"] as? Int,
            let typeString = messageBody["type"] as? String,
            let messageData = messageBody["data"] as? [String: AnyObject] else {
            LogNotify.log("Bad WebKit request received \(message.body)", level: LogNotify.LEVEL.ERROR)
            
            if let webView = message.webView as? WBWebView {
                webView.threadsafeEvaluateJavaScript("receiveMessage('badrequest');")
            }
           return nil
        }
        let typeComponents = typeString.components(separatedBy: ":")
        self.init(id: id, typeComponents: typeComponents, messageData: messageData, webView: message.webView)
    }
    
    /*
     * ========== Public methods ==========
     */
    /*! @abstract Abandon the transaction and release all completion handlers. */
    func abandon() {
        self.completionHandlers = []
        self.resolved = true
    }
    func addCompletionHandler(_ handler: @escaping (WBTransaction, Bool) -> Void) {
        self.completionHandlers.append(handler)
    }
    func resolveAsSuccess(withMessage message: String = "Success") {
        self.complete(success: true, object: message)
    }
    func resolveAsSuccess(withObject object: Jsonifiable) {
        self.complete(success: true, object: object)
    }
    func resolveAsFailure(withMessage message: String) {
        self.complete(success: false, object: message)
    }
    
    static func == (lhs: WBTransaction, rhs: WBTransaction) -> Bool {
        return lhs.id == rhs.id
    }
    
    /*
     * ========== CustomStringConvertible ==========
     */
    var description: String {
        return "Transaction(id: \(self.id), key: \(self.key))"
    }
    
    /*
     * ========== Private methods ==========
     */
    private func complete(success: Bool, object: Jsonifiable) {
        if self.resolved {
            NSLog("Attempt to re-resolve transaction \(self.id) ignored")
            return
        }
        
        let commandString = "window.receiveMessageResponse(\(success.jsonify()), \(object.jsonify()), \(self.id));\n"
        
        if !success {
            NSLog("\(self.description) unsuccessful: \(object.jsonify())")
        }
        
        if let wv = self.webView {
            wv.threadsafeEvaluateJavaScript(commandString)
        }
        else {
            LogNotify.log("Webview not configured on transaction or dealloced", level: LogNotify.LEVEL.ERROR)
        }
        self.resolved = true
        self.completionHandlers.forEach {$0(self, success)}
        self.completionHandlers.removeAll()
    }
}

class ServicesTransaction: WBTransaction.Wrapper {
    let serviceUUID: CBUUID?
    
    override init?(transaction: WBTransaction) {
        if let serviceUUIDString = transaction.messageData["serviceUUID"] as? String {
            guard let serviceUUID = UUID(uuidString: serviceUUIDString) else {
                return nil
            }
            self.serviceUUID = CBUUID(nsuuid: serviceUUID)
        } else {
            self.serviceUUID = nil
        }
        super.init(transaction: transaction)
    }
    
    func resolveFromServices(_ services: [CBService]) {
        let uuids = services.map{$0.uuid}.filter{
            self.serviceUUID == nil || self.serviceUUID == $0
        }
        if uuids.count > 0 {
            self.transaction.resolveAsSuccess(withObject: uuids)
        } else {
            self.transaction.resolveAsFailure(withMessage: self.serviceUUID != nil ? "Service \(self.serviceUUID!.uuidString) not known on device" : "No services found")
        }
    }
}

class ServiceTransaction: WBTransaction.Wrapper {
    let serviceUUID: CBUUID

    override init?(transaction: WBTransaction) {
        guard
            let serviceUUIDString = transaction.messageData["serviceUUID"] as? String,
            let serviceUUID = UUID(uuidString: serviceUUIDString)
            else {
                return nil
        }
        self.serviceUUID = CBUUID(nsuuid: serviceUUID)
        super.init(transaction: transaction)
    }

    func resolveUnknownService() {
        self.transaction.resolveAsFailure(withMessage: "Service \(self.serviceUUID.uuidString) not known on device")
    }
}

class CharacteristicTransaction: ServiceTransaction {
    let characteristicUUID: CBUUID

    override init?(transaction: WBTransaction) {
        guard
            let characteristicUUIDString = transaction.messageData["characteristicUUID"] as? String,
            let characteristicUUID = UUID(uuidString: characteristicUUIDString)
            else {
                return nil
        }
        self.characteristicUUID = CBUUID(nsuuid: characteristicUUID)
        super.init(transaction: transaction)
    }
    
    func matchesCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        guard
            let serviceUUID = characteristic.service?.uuid else {
                return false;
            }
        return (
            self.serviceUUID == serviceUUID
            && self.characteristicUUID == characteristic.uuid
        )
    }
    
    func resolveUnknownCharacteristic() {
        self.transaction.resolveAsFailure(withMessage: "Characteristic \(self.characteristicUUID.uuidString) not known for service \(self.serviceUUID.uuidString) on device")
    }
}

class CharacteristicsTransaction: ServiceTransaction {
    override init?(transaction: WBTransaction) {
        super.init(transaction: transaction)
    }
}

class WriteCharacteristicTransaction: CharacteristicTransaction {
    enum ResponseMode: String {
        case optional, required, never
    }

    let responseMode: ResponseMode
    let data: Data

    override init?(transaction: WBTransaction) {
        guard
            let dataString = transaction.messageData["value"] as? String,
            let data = Data(base64Encoded: dataString),
            let responseModeString = transaction.messageData["responseMode"] as? String,
            let responseMode = ResponseMode(rawValue: responseModeString)
        else {
            LogNotify.log("Invalid WriteCharacteristic message \(transaction.messageData)")
            return nil
        }
        self.data = data
        self.responseMode = responseMode
        super.init(transaction: transaction)
    }
}
