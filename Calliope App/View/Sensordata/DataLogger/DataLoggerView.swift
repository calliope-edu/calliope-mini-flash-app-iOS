//
//  DataLoggerView.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit

class DataLoggerWebView: WKWebView, WKNavigationDelegate, WKScriptMessageHandler {
    let saveCSV: (String) -> Void

    init(html: String, saveCSV: @escaping (String) -> Void) {
        self.saveCSV = saveCSV
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        super.init(frame: .zero, configuration: config)

        self.configuration.userContentController.add(self, name: "readBlob")
        self.navigationDelegate = self
        self.loadHTMLString(html, baseURL: nil)
        self.isInspectable = true

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url, url.absoluteString.hasPrefix("blob:") {
            // Handle the possible CSV download
            decisionHandler(.cancel)
            downloadFile(from: url)
            return
        }
        decisionHandler(.allow)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        LogNotify.log("Message name: \(message.name)")
        LogNotify.log("Message Body: \(message.body)")
        if message.name == "readBlob", let body = message.body as? String,
            body != "downloadHandler"
        {
            saveCSV(body)
        }
    }

    private func downloadFile(from url: URL) {
        var script = ""
        script = script + "var xhr = new XMLHttpRequest();"
        script = script + "xhr.open('GET', '\(url.absoluteString)', true);"
        script = script + "xhr.responseType = 'blob';"
        script = script + "window.webkit.messageHandlers.readBlob.postMessage('downloadHandler');"
        script =
            script
            + "xhr.onload = function(e) { if (this.status == 200) { var blob = this.response; window.webkit.messageHandlers.readBlob.postMessage(blob); var reader = new window.FileReader(); reader.readAsBinaryString(blob); reader.onloadend = function() { window.webkit.messageHandlers.readBlob.postMessage(reader.result); }}};"
        script = script + "xhr.send();"

        self.evaluateJavaScript(script) { (results, error) in
            LogNotify.log("\(results ?? "")")
        }
    }
}

struct RepresentedDataLoggerWebView: UIViewRepresentable {
    let html: String
    let saveCSV: (String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        return DataLoggerWebView(html: html, saveCSV: saveCSV)
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {

    }
}

struct DataLoggerDetailView: View {
    let url: URL
    @StateObject var viewModel: DataLoggerViewModel

    init(url: URL) {
        self.url = url
        _viewModel = StateObject(wrappedValue: DataLoggerViewModel(htmlData: (try? url.asData()) ?? Data()))
    }

    var body: some View {
        DataLoggerView(viewModel: viewModel)
    }
}

struct DataLoggerView: View {
    @ObservedObject var viewModel: DataLoggerViewModel

    var body: some View {
        RepresentedDataLoggerWebView(html: viewModel.html, saveCSV: viewModel.saveCSV)
            .modifier(AlertModifier(alert: viewModel.alertBinding))
    }
}
