//
//  HelpWebViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.08.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit
import WebKit

class HelpWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    @IBOutlet weak var webView: WKWebView!
    private var contentController: HelpContentViewController?
    
    var url: URL? = nil {
        didSet {
            loadUrl()
        }
    }
    
    func setContentController(controller:HelpContentViewController) {
        contentController = controller
    }

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        super.viewDidLoad()
        loadUrl()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError: Error) {
        handleError(title: "Error - DF", error: withError.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError: Error) {
        handleError(title: "Error - DFPN", error: withError.localizedDescription)
    }

    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        if error != nil {
            handleError(title: "Error - DFLWE", error: error?.localizedDescription ?? "wtf")
        }
    }
    
    func handleError(title: String, error: String) {
        if contentController != nil {
            contentController?.successfullyOnline = false
            navigationController?.popViewController(animated: false)
            return
        }
        let alert = UIAlertController(title: NSLocalizedString(title, comment: ""), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in })
        self.present(alert, animated: true)
    }

    private func loadUrl() {
        guard let webView = webView else {
            return
        }
        let blankUrl = URL(string: "about:blank")!
        webView.load(URLRequest(url: url ?? blankUrl))
    }
}
