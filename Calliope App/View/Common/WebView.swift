//
//  WebView.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @State var url: URL?
    @State var html: String?
    @State var navigationDelegate: WKNavigationDelegate?

    func makeUIView(context: Context) -> WebViewContainer {
        return WebViewContainer()
    }

    func updateUIView(_ container: WebViewContainer, context: Context) {
        container.navigationDelegate = navigationDelegate
        if url != nil {
            container.load(.request(URLRequest(url: url!.withCalliopeAppLayout)))
        } else if html != nil {
            container.load(.html(html!))
        }
    }
}

final class WebViewContainer: UIView {
    enum Content {
        case request(URLRequest)
        case html(String)
    }

    private var webView: WKWebView?
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private var loadingObservation: NSKeyValueObservation?
    private var pendingContent: Content?

    weak var navigationDelegate: WKNavigationDelegate? {
        didSet { webView?.navigationDelegate = navigationDelegate }
    }

    init() {
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

    func load(_ content: Content) {
        guard let webView else {
            pendingContent = content
            return
        }
        loadingIndicator.startAnimating()
        switch content {
        case .request(let request):
            webView.load(request)
        case .html(let html):
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    private func setupWebView() {
        let webView = WKWebView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = navigationDelegate
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
        // Observed instead of using the navigation delegate, which belongs to the caller
        loadingObservation = webView.observe(\.isLoading) { [weak self] webView, _ in
            if !webView.isLoading {
                self?.loadingIndicator.stopAnimating()
            }
        }
        self.webView = webView
        if let pendingContent {
            self.pendingContent = nil
            load(pendingContent)
        }
    }
}
