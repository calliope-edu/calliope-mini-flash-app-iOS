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
    }
}
