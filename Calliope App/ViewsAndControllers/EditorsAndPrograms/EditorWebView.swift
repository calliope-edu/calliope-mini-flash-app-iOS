//
//  EditorWebView.swift
//  Calliope App
//
//  Created by Calliope on 15.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit
import ScratchLinkKit

struct EditorWebViewRepresentable: UIViewRepresentable {
    let editor: Editor
    
    func makeUIView(context: Context) -> EditorWebView {
       return EditorWebView()
    }
    func updateUIView(_ editorWebView: EditorWebView, context: Context) {
        guard editor.url != nil else {
            LogNotify.error("Url of editor is nil. This should not happen.")
            return
        }
        editorWebView.load(url: editor.url!)
    }
}

final class EditorWebView: UIView {
    let webView = WKWebView(frame: .zero)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .systemBackground

        webView.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true

        addSubview(webView)
        addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func showLoading() {
        loadingIndicator.startAnimating()
    }

    func hideLoading() {
        loadingIndicator.stopAnimating()
    }
    
    func load(url: URL) {
       showLoading()
       var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        webView.load(request)
    }
}


/*struct Testing: UIViewRepresentable {
    let editor: Editor
    
    private let scratchLink = ScratchLink()

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .video

        // Enable persistent caching for offline support
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            LogNotify.log("Inspection of the webview is enabled in debug mode", level: LogNotify.LEVEL.DEBUG)
        }
        #endif
        
         webView.navigationDelegate = self
         webView.uiDelegate = self
        
        // Configure scroll view to better handle touches in web content
        // This helps with selecting items in MakeCode project lists
        webView.scrollView.delaysContentTouches = false
        webView.scrollView.canCancelContentTouches = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        scratchLink.setup(webView: webView)
        scratchLink.delegate = self
        
        webView.configuration.applicationNameForUserAgent = editor is BlocksMiniEditor ? "Scrub" : nil
        webView.customUserAgent = traitCollection.userInterfaceIdiom == .pad && !(editor is BlocksMiniEditor) ? "Mozilla/5.0 (iPad; CPU OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1" : nil
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard editor.url != nil else {
            LogNotify.error("Empty url of editor -- return")
            return
        }
        
        // Use protocol cache policy: respects HTTP cache headers when online,
        // falls back to cache when offline
        var request = URLRequest(url: editor.url!)
        request.cachePolicy = .useProtocolCachePolicy
        webView.load(request)

        
        
    }
}

extension EditorWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        LogNotify.log("policy for action \(navigationAction.request.url?.absoluteString.truncate(length: 100) ?? "")")
        
        let request = navigationAction.request
        
        if navigationAction.shouldPerformDownload && (editor is MicroPython || editor is CampusEditor){
            decisionHandler(.download)
        } else if let download = editor.download(request) {
            decisionHandler(.cancel)
            if download.url.absoluteString.starts(with: "data:text/xml") {
                export(download: download)
            } else {
                upload(result: download)
            }
        } else if editor.isBackNavigation(request) {
            decisionHandler(.cancel)
            self.navigationController?.popViewController(animated: true)
        } else if editor.allowNavigation(request) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        switch editor.getNavigationTargetViewForRequest(navigationAction.request) {
        case .internalWebView:
            return handleInternalWebView(navigationAction, webView)
        case .externalWebView:
            return handleExternalWebView(navigationAction)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        handlePossibleEditorChanges()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        LogNotify.log("\(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        LogNotify.log("\(error)")
    }
    
    // helper
    
    fileprivate func handleInternalWebView(_ navigationAction: WKNavigationAction, _ webView: WKWebView) -> WKWebView? {
        guard navigationAction.targetFrame != nil else {
            return nil
        }
        webView.load(navigationAction.request)
        return nil
    }


    fileprivate func handleExternalWebView(_ navigationAction: WKNavigationAction) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
}

extension EditorWebView: WKUIDelegate {
    func webView(
        _ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: ""), style: .default,
                handler: { (action) in
                    completionHandler()
                }))

        present(alertController, animated: true, completion: nil)
    }


    func webView(
        _ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: ""), style: .default,
                handler: { (action) in
                    completionHandler(true)
                }))

        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("Cancel", comment: ""), style: .default,
                handler: { (action) in
                    completionHandler(false)
                }))

        present(alertController, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {

        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.text = defaultText
        }

        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: ""), style: .default,
                handler: { (action) in
                    if let text = alertController.textFields?.first?.text {
                        completionHandler(text)
                    } else {
                        completionHandler(defaultText)
                    }
                }))

        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("Cancel", comment: ""), style: .default,
                handler: { (action) in
                    completionHandler(nil)
                }))

        present(alertController, animated: true, completion: nil)
    }   
}

extension EditorWebView: WKDownloadDelegate {
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        guard editor is MicroPython || editor is CampusEditor else {
            return
        }
        
        latestDownloadedTargetFile = prepareTemporaryStorage(for: suggestedFilename)
        try? FileManager.default.removeItem(at: latestDownloadedTargetFile!)
        completionHandler(latestDownloadedTargetFile)
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        guard let url = latestDownloadedTargetFile, let fileextension = FileExtension(rawValue: url.pathExtension.lowercased()) else {
            return
        }
        
        switch fileextension {
        case .hex:
            uploadHex(from: url)
        case .html, .json:
            storeSessionData(for: url)
        }
        
    }
    
    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        LogNotify.log("Download failed: \(error)")
        self.clearTemporaryStorage()
    }
   
    // MARK: Helper
    
    private func prepareTemporaryStorage(for name: String) -> URL? {
        return NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
    }
    
    private func clearTemporaryStorage() {
        guard let latestDownloadedTargetFile = latestDownloadedTargetFile else {
            return
        }
        
        try? FileManager.default.removeItem(at: latestDownloadedTargetFile)
        self.latestDownloadedTargetFile = nil
    }
    
    private func uploadHex(from location: URL) {
        LogNotify.log("Treating downloaded file as a Hex-File for the mini: \(location.absoluteString)")
        guard location.isFileURL, FileExtension(rawValue: location.pathExtension.lowercased()) == .hex else {
            LogNotify.log("Location of hex file was not provided or target at locationis not a hex file.")
            return
        }
        
        let file = HexFile(url: location, name: location.lastPathComponent, date: Date())
        FirmwareUpload.uploadWithoutConfirmation(controller: self, program: file) {
            MatrixConnectionViewModel.instance.connect()
            self.clearTemporaryStorage()
        }
    }
    
    private func storeSessionData(for location: URL) {
        LogNotify.log("Treating downloaded file as session relevant data: \(location.absoluteString)")
        guard location.isFileURL, [FileExtension.html, FileExtension.json].contains(FileExtension(rawValue: location.pathExtension.lowercased())) else {
            LogNotify.log("Location of session data file was not provided, or is neither in json or html format")
            return
        }
        
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(location.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            showAlertSessionDataDownload(for: .success)
        } catch {
            showAlertSessionDataDownload(for: .failure)
        }
    }
    
     
    private func showAlertSessionDataDownload(for status: OperationStatus) {
        let title =
            switch status {
            case .success: NSLocalizedString("Session data successfully downloaded!", comment: "")
            default: NSLocalizedString("Failed to download session data!", comment: "")
            }

        let message =
            switch status {
            case .success: NSLocalizedString("You can find the session data, in the Calliope directory on your device.", comment: "")
            default: NSLocalizedString("The download of the session data was unsuccessful.", comment: "")
            }

        let alert = UIAlertController(
            title: title,
            message: String(format: message),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "OK", style: .cancel) { _ in
                self.dismiss(animated: true)
            }
        )
        self.present(alert, animated: true)
    }
}

extension EditorWebView: ScratchLinkDelegate {
    func canStartSession(type: ScratchLinkKit.SessionType) -> Bool {
        LogNotify.log("Call to 'canStartSession'")
        return true
    }
    
    func didStartSession(type: ScratchLinkKit.SessionType) {
        LogNotify.log("Call to 'didStartSession'")
    }
    
    func didFailStartingSession(type: ScratchLinkKit.SessionType, error: ScratchLinkKit.SessionError) {
        LogNotify.log("Call to 'didFailStartingSession'")
    }
}
*/
