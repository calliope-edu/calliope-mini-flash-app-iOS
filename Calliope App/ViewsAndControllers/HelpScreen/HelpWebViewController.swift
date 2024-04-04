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
    var activityIndicator: UIActivityIndicatorView!
    
    private var contentController: HelpContentViewController?
    
    private var initialLoadPerformed: Bool = false
    
    var url: URL = URL(string: "https://calliope.cc/programmieren/mobil/hilfe#top")!
    
    func setContentController(controller:HelpContentViewController) {
        contentController = controller
    }

    override func viewDidLoad() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        super.viewDidLoad()
        initialLoadPerformed = false
        
        // add activity indicator
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = UIActivityIndicatorView.Style.gray
        
        view.addSubview(activityIndicator)
        showActivityIndicator(show: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        initialLoadPerformed = false
        showActivityIndicator(show: true)
        webView.load(URLRequest(url: url))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError: Error) {
        let backItem = UIBarButtonItem()
        backItem.title = "Zurück zur Online Ansicht"
        navigationItem.backBarButtonItem = backItem
        if !initialLoadPerformed {
            performSegue(withIdentifier: "showOfflineFallback", sender: nil)
            initialLoadPerformed = true
        }
    }

    func webView(webView: WKWebView, didFailLoadWithError error: NSError?) {
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

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleError(title: "Error - DF", error: error.localizedDescription)
        showActivityIndicator(show: false)
    }
}
