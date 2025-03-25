//
//  DataLoggerViewController.swift
//  Calliope App
//
//  Created by Calliope on 11.03.25.
//  Copyright © 2025 calliope. All rights reserved.
//

import UIKit
import WebKit

class DataLoggerViewController: UIViewController {
    @IBOutlet var webview: WKWebView!

    private var html: String?
    var htmlData: Data {
        get {
            html?.data(using: .utf8) ?? Data()
        }
        set {
            html = String(decoding: newValue, as: UTF8.self)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadWebView()
    }

    func loadWebView() {
        guard let html = html else {
            LogNotify.log("No HTML provided to display")
            return
        }
        webview.loadHTMLString(html, baseURL: nil)
    }
}
