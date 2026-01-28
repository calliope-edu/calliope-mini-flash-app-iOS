//
//  WebLogHandler.swift
//  Calliope App
//
//  Created by Calliope on 11.07.25.
//  Copyright © 2025 calliope. All rights reserved.
//
//  Base on https://stackoverflow.com/a/66110779
//

import Foundation
import WebKit

class WebLogHandler: NSObject, WKScriptMessageHandler {
    
    enum LEVEL: String {
        case INFO, WARN, ERROR
    }
    public static let ALL_LEVELS: [LEVEL] = [.INFO, .WARN, .ERROR]
        
    let messageName = "logHandler"

    lazy var loggerScript: String = {
        return """
        function stringifySafe(obj) {
            try {
                return JSON.stringify(obj)
            }
            catch (err) {
                return "Stringify error"
            }
        }
        
        function log(type, args) {
          window.webkit.messageHandlers.\(messageName).postMessage(
            `[JS ${type}] ${Object.values(args)
              .map(v => typeof(v) === "undefined" ? "undefined" : typeof(v) === "object" ? stringifySafe(v) : v.toString())
              .map(v => v.substring(0, 3000)) 
              .join(", ")}`
          )
        }
        
        let originalLog = console.log
        """
    }()
    
    lazy var attachInfo: String = {
       "console.log = function() { log('INFO', arguments); originalLog.apply(null, arguments) }"
    }()

    lazy var attachWarn: String = {
       "console.warn = function() { log('WARN', arguments); originalLog.apply(null, arguments) }"
    }()
    
    lazy var attachError: String = {
       "console.error = function() { log('ERROR', arguments); originalLog.apply(null, arguments) }"
    }()

    func register(with userContentController: WKUserContentController, _ levels: [LEVEL] = [.INFO]) {
        userContentController.add(self, name: messageName)
        let loggerScript = attachLogger(with: levels)
        // inject JS to capture console.log output and send to iOS
        let script = WKUserScript(source: loggerScript,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        userContentController.addUserScript(script)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        LogNotify.log(message.body as? String ?? "")
    }
    
    private func attachLogger(with levels: [LEVEL]) -> String {
        var finalLoggerScript = loggerScript.appending("\n")
        
        if levels.contains(.ERROR) {
            finalLoggerScript.append(attachError)
            finalLoggerScript.append("\n")
        }
        
        if levels.contains(.WARN) {
            finalLoggerScript.append(attachWarn)
            finalLoggerScript.append("\n")
        }
        
        if levels.contains(.INFO) {
            finalLoggerScript.append(attachInfo)
            finalLoggerScript.append("\n")
        }
       
        return finalLoggerScript
    }
}
