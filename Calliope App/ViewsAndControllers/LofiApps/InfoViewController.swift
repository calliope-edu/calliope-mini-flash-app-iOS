//
//  InfoViewController.swift
//  Calliope App
//
//  Created by Calliope on 27.02.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import WebKit

class InfoViewController: UIViewController {
    @IBOutlet var webView: WKWebView!
    public var url: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Apps Info"
        self.webView.load(URLRequest(url: url))        
    }
}
