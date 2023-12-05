//
//  OnboardingDetailWebViewController.swift
//  Calliope App
//
//  Created by itestra on 04.12.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import UIKit
import WebKit

class OnboardingDetailWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    @IBOutlet weak var webView: WKWebView!
    var activityIndicator: UIActivityIndicatorView!
    
    
    private var url: URL = URL(string: "https://calliope.cc/programmieren/mobil/ipad")!
    private var initialLoadPerformed: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isHidden = true
        initialLoadPerformed = false
        
        // add activity
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = UIActivityIndicatorView.Style.gray

        view.addSubview(activityIndicator)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        webView.load(URLRequest(url: url))
        webView.isHidden = false
    }

    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.isHidden = true
        
        let backItem = UIBarButtonItem()
        backItem.title = "Zurück zur Online Ansicht"
        navigationItem.backBarButtonItem = backItem
        if !initialLoadPerformed {
            performSegue(withIdentifier: "showOfflineFallback", sender: nil)
            initialLoadPerformed = true
        }
    }
    
    func showActivityIndicator(show: Bool) {
        if show {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        showActivityIndicator(show: false)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showActivityIndicator(show: true)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showActivityIndicator(show: false)
        }
}
