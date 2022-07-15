//
//  HelpWebViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.08.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit
import WebKit

class HelpWebViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView!

    var url: URL? = nil {
        didSet {
            loadUrl()
        }
    }

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
        loadUrl()
    }

    private func loadUrl() {
        guard let webView = webView else {
            return
        }
        let blankUrl = URL(string: "about:blank")!
        webView.load(URLRequest(url: url ?? blankUrl))
    }
}
