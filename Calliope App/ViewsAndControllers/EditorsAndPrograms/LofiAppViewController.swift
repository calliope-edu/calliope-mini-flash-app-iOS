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

    @IBOutlet var webView: WKWebView!
    
    public var url: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        print("View loaded")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            print("Inspection enabled")
        } else {
            // Fallback on earlier versions
        }

        webView.load(URLRequest(url: url))
    }
}
