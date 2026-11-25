//
//  WebBluetoothBridge.swift
//  Calliope App
//
//  Created by Calliope on 25.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import WebKit

final class WebBluetoothBridge: NSObject, WKNavigationDelegate {
    private static let handlerName = "bluetooth"
    private static let polyfillFiles = [
        "WBUtils",
        "WBEventTarget",
        "WBBluetoothUUID",
        "WBDevice",
        "WBBluetoothRemoteGATTServer",
        "WBBluetoothRemoteGATTService",
        "WBBluetoothRemoteGATTCharacteristic",
        "WBPolyfill",
    ]

    private let messageHandler: WBMessageHandler

    init(webView: WBWebView, connection: DeviceConnectionService) {
        messageHandler = WBMessageHandler(webView: webView, connection: connection)
        super.init()
    }

    // MARK: - Public API

    func install(in webView: WBWebView) {
        let userContentController = webView.configuration.userContentController
        for fileName in Self.polyfillFiles {
            guard
                let filePath = Bundle.main.path(forResource: fileName, ofType: "js"),
                let source = try? String(contentsOfFile: filePath, encoding: .utf8)
            else {
                LogNotify.log("Failed to load Web Bluetooth polyfill \(fileName)", level: LogNotify.LEVEL.ERROR)
                return
            }
            userContentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        userContentController.add(messageHandler, name: Self.handlerName)
        webView.addNavigationDelegate(self)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Pages can overwrite navigator.bluetooth while loading.
        webView.evaluateJavaScript("window.iOSNativeAPI.enableBluetooth()") { _, error in
            if let error {
                LogNotify.log("Error enabling bluetooth in view: \(error)", level: LogNotify.LEVEL.ERROR)
            }
        }
    }
}
