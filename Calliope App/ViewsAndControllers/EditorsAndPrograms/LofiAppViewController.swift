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

class LofiAppViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    public var url: URL!

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
        self.webView.load(URLRequest(url: url))
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            LogNotify.log("Inspection of the webview is enabled in debug mode", level: LogNotify.LEVEL.DEBUG)
        }
        #endif
        if let calliope = MatrixConnectionViewController.instance.usageReadyCalliope,
        calliope is BLECalliope {
                (calliope as! BLECalliope).view = webView
        }
        else {
            print("Please connect a calliope via bluetooth before opening this page.")
        }
        
    }
}
