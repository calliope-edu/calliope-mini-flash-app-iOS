//
//  WBWebViewController.swift
//  WebBLE
//
//  Created by David Park on 07/09/2019.
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
    }
}
