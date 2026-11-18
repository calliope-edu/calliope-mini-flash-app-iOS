//
//  WBWebViewController.swift
//  WebBLE
//
//  Created by David Park on 07/09/2019.
//  Copyright 2019 David Park.
//  Modified by Calliope gGmbH, 2026.
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

import UIKit
import WebKit

class WBWebViewController: UIViewController, WKNavigationDelegate {
    class WBLogger: NSObject, WKScriptMessageHandler {

        // MARK: - WKScriptMessageHandler
        open func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
            ) {
            switch (message.body) {
            case let bodyDict as [String: Any]:
                guard
                    let levelString = bodyDict["level"] as? String,
                    let message = bodyDict["message"] as? String
                    else {
                        NSLog("Badly formed dictionary \(bodyDict.description) passed to the logger")
                        return
                }
                LogNotify.log("Log from WB Webview with level \(levelString): \(message)", level: LogNotify.LEVEL.DEBUG)
            case let bodyString as String:
                LogNotify.log("Log from WB Webview: \(bodyString)", level: LogNotify.LEVEL.DEBUG)
            default:
                LogNotify.log("Unexpected message type from console log: \(message.body)", level: LogNotify.LEVEL.DEBUG)
            }
        }
    }
    let wbLogger = WBLogger()

    var webView: WBWebView {
        get {
            return self.view as! WBWebView
        }
    }

    override func viewDidLoad() {
        self.webView.addNavigationDelegate(self)
       // Add logging script
        self.webView.configuration.userContentController.add(
            self.wbLogger, name: "logger"
        )
        
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            LogNotify.log("Inspection of the webview is enabled in debug mode", level: LogNotify.LEVEL.DEBUG)
        }
        #endif
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.webView.removeNavigationDelegate(self)
    }
}
