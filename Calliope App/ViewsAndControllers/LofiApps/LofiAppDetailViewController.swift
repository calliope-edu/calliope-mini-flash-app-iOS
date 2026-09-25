//
//  LofiAppViewController.swift
//  Calliope App
//
//  Created by Calliope on 16.01.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation


import UIKit
@preconcurrency import WebKit

class LofiAppDetailViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    public var url: URL!
    public var appTitle: String!

    /// Native-proxy bridge, non-nil only for app pages that use the Campus API
    /// (currently teachablemachine.calliope.cc). Every other page keeps the
    /// Web-Bluetooth shim that `WBWebView` provides on its own.
    private var proxyMessageHandler: CalliopeProxyMessageHandler?
    
    var WBWebViewContainerController: WBWebViewContainerController {
        get {
            return self.children.first(where: {$0 as? WBWebViewContainerController != nil}) as! WBWebViewContainerController
        }
    }
    var webView: WBWebView {
        get {
            return self.WBWebViewContainerController.webView
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = appTitle

        // Register the bridge BEFORE loading: the page probes
        // `window.webkit?.messageHandlers?.calliope` at script start, and a
        // handler added later would arrive after that check.
        //
        // Note `webView.configuration.userContentController` — the LIVE
        // controller. WKWebView copies its configuration when it is created, so
        // a handler added anywhere else would never reach the running page.
        if CalliopeProxyMessageHandler.supportsNativeBridge(url: url) {
            let handler = CalliopeProxyMessageHandler(webView: webView)
            proxyMessageHandler = handler
            webView.configuration.userContentController.add(
                handler, name: CalliopeProxyMessageHandler.handlerName)
            LogNotify.log("Native bridge enabled for \(url.host ?? "unknown host")")
        }

        self.webView.load(URLRequest(url: url.withCalliopeAppLayout))
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            LogNotify.log("Inspection of the webview is enabled in debug mode", level: LogNotify.LEVEL.DEBUG)
        }
        #endif
        
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // WKUserContentController retains script-message handlers strongly, so
        // without an explicit removal the handler — and the BLE observers it
        // installs — would outlive this screen.
        if proxyMessageHandler != nil {
            webView.configuration.userContentController.removeScriptMessageHandler(
                forName: CalliopeProxyMessageHandler.handlerName)
            proxyMessageHandler = nil
        }
    }
}
