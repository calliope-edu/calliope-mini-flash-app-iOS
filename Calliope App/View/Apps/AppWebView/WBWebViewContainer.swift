//
//  WBWebViewContainer.swift
//  WebBLE
//
//  Created by David Park on 23/09/2019.
//  Copyright 2019 David Park.
//  Modified by Calliope gGmbH, 2026.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import WebKit

final class WBWebViewContainer: UIView, WKNavigationDelegate, WKUIDelegate {
    private final class WBLogger: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.body {
            case let bodyDict as [String: Any]:
                guard
                    let levelString = bodyDict["level"] as? String,
                    let message = bodyDict["message"] as? String
                else {
                    NSLog("Badly formed dictionary \(bodyDict.description) passed to the logger")
                    return
                }
                LogNotify.log("Log from WB Webview with level \(levelString): \(message)", level: LogNotify.LEVEL.DEBUG)
            case let bodyString as String:
                LogNotify.log("Log from WB Webview: \(bodyString)", level: LogNotify.LEVEL.DEBUG)
            default:
                LogNotify.log("Unexpected message type from console log: \(message.body)", level: LogNotify.LEVEL.DEBUG)
            }
        }
    }

    private let alertPublisher: Alertable
    private let connection: DeviceConnectionService
    private let connectionPanel: ConnectionPanel

    private var webView: WBWebView?
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let wbLogger = WBLogger()
    private var pendingURL: URL?
    private var loadedURL: URL?
    private var urlObservation: NSKeyValueObservation?

    /// Native-proxy bridge, non-nil only for pages that use the Campus API
    /// (currently teachablemachine.calliope.cc). Every other page keeps the
    /// Web Bluetooth shim that `WBWebView` enables on its own.
    private var proxyMessageHandler: CalliopeProxyMessageHandler?

    init(alertPublisher: Alertable, connection: DeviceConnectionService, connectionPanel: ConnectionPanel) {
        self.alertPublisher = alertPublisher
        self.connection = connection
        self.connectionPanel = connectionPanel
        super.init(frame: .zero)
        backgroundColor = Styles.colorWhite
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        loadingIndicator.startAnimating()
        // Creating the first WKWebView blocks the main thread; deferring it lets the navigation push render first
        DispatchQueue.main.async { [weak self] in
            self?.setupWebView()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - API

    func load(url: URL) {
        guard url != loadedURL else {
            return
        }
        guard let webView else {
            pendingURL = url
            return
        }
        loadedURL = url
        enableNativeBridgeIfNeeded(for: url, in: webView)
        webView.load(URLRequest(url: url))
    }

    func removeHandlers() {
        webView?.removeNavigationDelegate(self)

        // WKUserContentController retains script-message handlers strongly, so
        // without an explicit removal the handler — and the BLE observers it
        // installs — would outlive this screen.
        if proxyMessageHandler != nil {
            webView?.configuration.userContentController.removeScriptMessageHandler(
                forName: CalliopeProxyMessageHandler.handlerName)
            proxyMessageHandler = nil
        }
    }

    // MARK: - Setup

    private func setupWebView() {
        let webView = WBWebView()
        webView.wbMessageHandler = WBMessageHandler(webView: webView, connection: connection)
        webView.addNavigationDelegate(self)
        webView.uiDelegate = self
        webView.configuration.userContentController.add(wbLogger, name: "logger")
        // KVO on url also catches the Teachable Machine SPA's pushState navigations, which skip the navigation delegate.
        urlObservation = webView.observe(\.url) { [weak self] _, _ in
            self?.updateScrollEnabled()
        }

        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            LogNotify.log("Inspection of the webview is enabled in debug mode", level: LogNotify.LEVEL.DEBUG)
        }
        #endif

        insertSubview(webView, at: 0)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        self.webView = webView

        if let pendingURL {
            self.pendingURL = nil
            load(url: pendingURL)
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
    private func enableNativeBridgeIfNeeded(for url: URL, in webView: WBWebView) {
        guard proxyMessageHandler == nil, CalliopeProxyMessageHandler.supportsNativeBridge(url: url) else {
            return
        }

        let handler = CalliopeProxyMessageHandler(webView: webView, connection: connection, connectionPanel: connectionPanel)
        proxyMessageHandler = handler
        webView.configuration.userContentController.add(
            handler, name: CalliopeProxyMessageHandler.handlerName)
        LogNotify.log("Native bridge enabled for \(url.host ?? "unknown host")")
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadingIndicator.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
        maybeShowErrorUI(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
        maybeShowErrorUI(error)
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        alertPublisher.alert = .ok(title: message, completion: completionHandler)
    }

    // MARK: - Private Helpers

    private func updateScrollEnabled() {
        guard let webView, let url = webView.url, url.host == "teachablemachine.calliope.cc" else {
            webView?.scrollView.isScrollEnabled = true
            return
        }
        let isHomepage = url.path.isEmpty || url.path == "/"
        webView.scrollView.isScrollEnabled = isHomepage
    }

    private func maybeShowErrorUI(_ error: Error) {
        let nserror = error as NSError
        if nserror.domain == NSURLErrorDomain && nserror.code == NSURLErrorCancelled {
            return
        }
        alertPublisher.alert = .webViewNavigationError(error: error)
    }
}
