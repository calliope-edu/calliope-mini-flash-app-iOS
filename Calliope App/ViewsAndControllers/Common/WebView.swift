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

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if url != nil {
            let request = URLRequest(url: url!)
            webView.load(request)
        } else if html != nil {
            webView.loadHTMLString(html!, baseURL: nil)
        }
    }
}
