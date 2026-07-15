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

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            LogNotify.log("Inspection of the webview is enabled in debug mode", level: LogNotify.LEVEL.DEBUG)
        }
        #endif
        if url != nil {
            let request = URLRequest(url: url!)
            webView.load(request)
        } else if html != nil {
            webView.loadHTMLString(html!, baseURL: nil)
        }
        if navigationDelegate != nil {
            webView.navigationDelegate = navigationDelegate
        }
    }
}
