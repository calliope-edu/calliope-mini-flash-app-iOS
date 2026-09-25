//
//  WBWebViewContainerController.swift
//  WebBLE
//
//  Created by David Park on 23/09/2019.
//

import UIKit
import WebKit

protocol ConsoleToggler {
    func toggleConsole()
}

class WBWebViewContainerController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    enum prefKeys: String {
        case lastLocation
    }
    
    @IBOutlet var loadingProgressContainer: UIView!
    @IBOutlet var loadingProgressView: UIView!
    
    var alertPublisher: Alertable!

    /// Native-proxy bridge, non-nil only for pages that use the Campus API
    /// (currently teachablemachine.calliope.cc). Every other page keeps the
    /// Web Bluetooth shim that `WBWebView` enables on its own.
    private var proxyMessageHandler: CalliopeProxyMessageHandler?

    var webViewController: WBWebViewController {
        get {
            return self.children.first(where: {$0 as? WBWebViewController != nil}) as! WBWebViewController
        }
    }
    var webView: WBWebView {
        get {
            return self.webViewController.webView
        }
    }
    
    // MARK: - View Event handling
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.webView.addNavigationDelegate(self)
        self.webView.uiDelegate = self
        
        for path in ["estimatedProgress"] {
            self.webView.addObserver(self, forKeyPath: path, options: .new, context: nil)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        // On the new IOS version the gestureRecognizer creates unwanted behaviour, because swipes are not always for navigating back.
        if #available(iOS 26.0, *), let gestureRecognizer = self.navigationController?.interactiveContentPopGestureRecognizer {
            gestureRecognizer.isEnabled = false
        }
    }
    
    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.loadingProgressContainer.isHidden = false
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let urlString = webView.url?.absoluteString,
            urlString != "about:blank" {
            UserDefaults.standard.setValue(urlString, forKey: WBWebViewContainerController.prefKeys.lastLocation.rawValue)
        }
        self.loadingProgressContainer.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.loadingProgressContainer.isHidden = true
        self._maybeShowErrorUI(error)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self._maybeShowErrorUI(error)
    }
    
    // MARK: - WKUIDelegate
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (@escaping () -> Void)) {
        alertPublisher.alert = .ok(title: message, completion: completionHandler)
    }
    
    // MARK: - Observe protocol
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard
            let defKeyPath = keyPath,
            let defChange = change
            else {
                NSLog("Unexpected change with either no keyPath or no change dictionary!")
                return
        }
        switch defKeyPath {
        case "estimatedProgress":
            let estimatedProgress = defChange[NSKeyValueChangeKey.newKey] as! Double
            let fwidth = self.loadingProgressContainer.frame.size.width
            let newWidth: CGFloat = CGFloat(estimatedProgress) * fwidth
            if newWidth < self.loadingProgressView.frame.size.width {
                self.loadingProgressView.frame.size.width = newWidth
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    self.loadingProgressView.frame.size.width = newWidth
                })
            }
        default:
            NSLog("Unexpected change observed by ViewController: \(defKeyPath)")
        }
    }

    /// Registers the Campus native-proxy bridge for `url` if it's a Campus
    /// page, instead of the Web Bluetooth shim. No-op once already enabled.
    ///
    /// Must run before `load`: the page probes
    /// `window.webkit?.messageHandlers?.calliope` at script start, and a
    /// handler added later would arrive too late. Uses
    /// `webView.configuration.userContentController` — the LIVE controller —
    /// since the webview already exists here, unlike a freshly created one.
    func enableNativeBridgeIfNeeded(for url: URL) {
        guard proxyMessageHandler == nil, CalliopeProxyMessageHandler.supportsNativeBridge(url: url) else {
            return
        }

        let handler = CalliopeProxyMessageHandler(webView: webView)
        proxyMessageHandler = handler
        webView.configuration.userContentController.add(
            handler, name: CalliopeProxyMessageHandler.handlerName)
        LogNotify.log("Native bridge enabled for \(url.host ?? "unknown host")")
    }

    private func _maybeShowErrorUI(_ error: Error) {
        let nserror = error as NSError
        if (
            nserror.domain == NSURLErrorDomain
            && nserror.code == NSURLErrorCancelled
        ) {
            return
        }
        self.alertPublisher.alert = .webViewNavigationError(error: error)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webView.removeNavigationDelegate(self)

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
