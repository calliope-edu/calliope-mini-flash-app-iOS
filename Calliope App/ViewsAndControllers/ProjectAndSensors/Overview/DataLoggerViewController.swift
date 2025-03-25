//
//  DataLoggerViewController.swift
//  Calliope App
//
//  Created by Calliope on 25.03.25.
//  Copyright © 2025 calliope. All rights reserved.
//


//
//  DataLoggerViewController.swift
//  Calliope App
//
//  Created by Calliope on 11.03.25.
//  Copyright © 2025 calliope. All rights reserved.
//

import UIKit
@preconcurrency import WebKit

class DataLoggerViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {


    @IBOutlet var webview: WKWebView!

    private var html: String?
    var htmlData: Data {
        get {
            html?.data(using: .utf8) ?? Data()
        }
        set {
            html = String(decoding: newValue, as: UTF8.self)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // configuration
        webview.configuration.userContentController.add(self, name: "readBlob")

        // preferences
        webview.allowsBackForwardNavigationGestures = true

        // check that data is present to display
        guard let html = html else {
            LogNotify.log("No HTML provided to display")
            return
        }

        //display
        webview.navigationDelegate = self
        webview.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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
            saveCSV(csv: body)
        }
    }

    private func downloadFile(from url: URL) {
        var script = ""
        script = script + "var xhr = new XMLHttpRequest();"
        script = script + "xhr.open('GET', '\(url.absoluteString)', true);"
        script = script + "xhr.responseType = 'blob';"
        script = script + "window.webkit.messageHandlers.readBlob.postMessage('downloadHandler');"
        script = script + "xhr.onload = function(e) { if (this.status == 200) { var blob = this.response; window.webkit.messageHandlers.readBlob.postMessage(blob); var reader = new window.FileReader(); reader.readAsBinaryString(blob); reader.onloadend = function() { window.webkit.messageHandlers.readBlob.postMessage(reader.result); }}};"
        script = script + "xhr.send();"

        self.webview.evaluateJavaScript(script) { (results, error) in
            LogNotify.log("\(results ?? "")")
        }
    }

    private func saveCSV(csv: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("MY_DATA.csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            print("File saved to: \(fileURL.path)")
        } catch {
            print("Error saving file: \(error)")
        }
    }
}
