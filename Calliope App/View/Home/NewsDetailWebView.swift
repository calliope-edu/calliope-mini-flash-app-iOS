//
//  NewsDetailWebViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 30.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import SwiftUI
import UIKit
import WebKit

struct NewsDetailWebView: View {
    let url: URL
    let navigationDelegate: NewsDetailWebViewNavigationDelegate
    
    init(url: URL, onLoadingFailed: @escaping () -> Void) {
        self.url = url
        self.navigationDelegate = NewsDetailWebViewNavigationDelegate(onLoadingFailed: onLoadingFailed)
    }

    var body: some View {
        WebView(url: url, navigationDelegate: navigationDelegate)
    }

}

class NewsDetailWebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    let onLoadingFailed: () -> Void
    
    init(onLoadingFailed: @escaping () -> Void) {
        self.onLoadingFailed = onLoadingFailed
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoadingFailed()
    }
}
