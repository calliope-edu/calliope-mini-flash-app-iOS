//
//  EditorWebView.swift
//  Calliope App
//
//  Created by Calliope on 15.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import ScratchLinkKit
import SwiftUI
import WebKit

struct PopupEditorWebView: View {
    let editor: Editor

    var body: some View {
        PopupRoot {
            EditorWebViewRepresentable(editor: editor, showPopup: showPopup, uploadFirmware: FirmwareUploadSwiftUI.uploadWithoutConfirmation)
        }
    }

    func showPopup(_ popup: Popup) {
        PopupManager.instance.show(popup)
    }
}

struct EditorWebViewRepresentable: UIViewRepresentable {
    let editor: Editor
    let showPopup: (_ popup: Popup) -> Void
    let uploadFirmware: (_ program: HexFile, _ completion: (() -> Void)?) -> Void

    func makeUIView(context: Context) -> EditorWebView {
        return EditorWebView(frame: .zero, showPopup: showPopup, uploadFirmware: uploadFirmware)
    }

    func updateUIView(_ editorWebView: EditorWebView, context: Context) {
        editorWebView.load(editor: editor)
    }
}

final class EditorWebView: UIView {
    @State var alertInputText = ""
    var webView: WKWebView?
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    var editor: Editor?

    let showPopup: (_ popup: Popup) -> Void
    let uploadFirmware: (_ program: HexFile, _ completion: (() -> Void)?) -> Void

    private var latestDownloadedTargetFile: URL?
    var documentsPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var downloadsPath: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    private let scratchLink = ScratchLink()

    let filenameQuery = "document.querySelector('input#fileNameInput2').value"

    init(
        frame: CGRect,
        showPopup: @escaping (_ popup: Popup) -> Void,
        uploadFirmware: @escaping (_ program: HexFile, _ completion: (() -> Void)?) -> Void
    ) {
        self.showPopup = showPopup
        self.uploadFirmware = uploadFirmware
        super.init(frame: frame)
        setupLoadingIndicator()
        webView = setupWebView()
        scratchLink.setup(webView: webView!)
        scratchLink.delegate = self
    }

    required init?(coder: NSCoder) {
        self.showPopup = { popup in }
        self.uploadFirmware = { program, completion in }
        super.init(coder: coder)
        setupLoadingIndicator()
        webView = setupWebView()
        scratchLink.setup(webView: webView!)
        scratchLink.delegate = self
    }

    private func setupLoadingIndicator() {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true

        addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func setupWebView() -> WKWebView {
        backgroundColor = Styles.colorWhite

        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .video
        // Enable persistent caching for offline support
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = Styles.colorWhite

        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Configure scroll view to better handle touches in web content
        // This helps with selecting items in MakeCode project lists
        webView.scrollView.delaysContentTouches = false
        webView.scrollView.canCancelContentTouches = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        #if DEBUG
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
                LogNotify.log("Inspection of the webView is enabled in debug mode", level: LogNotify.LEVEL.DEBUG)
            }
        #endif

        insertSubview(webView, at: 0)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        return webView
    }

    func showLoading() {
        loadingIndicator.startAnimating()
    }

    func hideLoading() {
        loadingIndicator.stopAnimating()
    }

    func load(editor: Editor) {
        guard editor.url != nil else {
            LogNotify.error("Url of editor is nil. This should not happen.")
            return
        }
        self.editor = editor
        guard webView != nil else {
            LogNotify.error("WebView is nil. This should not happen.")
            return
        }
        showLoading()

        webView!.configuration.applicationNameForUserAgent = editor is BlocksMiniEditor ? "Scrub" : nil
        webView!.customUserAgent =
            traitCollection.userInterfaceIdiom == .pad && !(editor is BlocksMiniEditor)
            ? "Mozilla/5.0 (iPad; CPU OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1"
            : nil

        var request = URLRequest(url: editor.url!)
        request.cachePolicy = .useProtocolCachePolicy
        webView!.load(request)
    }
}

extension EditorWebView: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let editor = editor else {
            return
        }

        LogNotify.log("policy for action \(navigationAction.request.url?.absoluteString.truncate(length: 100) ?? "")")

        let request = navigationAction.request

        if navigationAction.shouldPerformDownload && (editor is MicroPython || editor is CampusEditor) {
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
            //            self.navigationController?.popViewController(animated: true) TODO: Close Editor
        } else if editor.allowNavigation(request) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let editor = editor else {
            return nil
        }

        switch editor.getNavigationTargetViewForRequest(navigationAction.request) {
        case .internalWebView:
            return handleInternalWebView(navigationAction, webView)
        case .externalWebView:
            return handleExternalWebView(navigationAction)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        hideLoading()
        handlePossibleEditorChanges()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
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
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {

        let popup = OkAlert(title: message, completion: completionHandler)
        showPopup(popup)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {

        let popup = TwoOptionsAlert(
            title: message,
            actions: [
                AlertAction(title: "OK", action: { completionHandler(true) }), AlertAction(title: "Cancel", action: { completionHandler(false) }),
            ]
        )
        showPopup(popup)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {

        let popup = SwiftUIAlert(
            title: prompt,
            actions: [
                AlertAction(
                    title: "OK",
                    action: {
                        completionHandler(self.alertInputText)
                    }
                ), AlertAction(title: "Cancel", action: { completionHandler(nil) }),
            ],
            textField: AlertTextField(title: "", text: $alertInputText)
        )
    }
}

extension EditorWebView: WKDownloadDelegate {

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        guard let editor = editor, editor is MicroPython || editor is CampusEditor else {
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
        uploadFirmware(file) {
            MatrixConnectionViewModel.instance.connect()
            self.clearTemporaryStorage()
        }
    }

    private func storeSessionData(for location: URL) {
        LogNotify.log("Treating downloaded file as session relevant data: \(location.absoluteString)")
        guard location.isFileURL, [FileExtension.html, FileExtension.json].contains(FileExtension(rawValue: location.pathExtension.lowercased()))
        else {
            LogNotify.log("Location of session data file was not provided, or is neither in json or html format")
            return
        }

        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(
            location.lastPathComponent
        )
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
        
        let popup = OkAlert(title: message)
        showPopup(popup)
        
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

extension EditorWebView {
    // MARK: Handle possible editor change (i.e. Scratch Based with own BLE connection)

    private func handlePossibleEditorChanges() {
        determineIfScratchBasedEditor { self.switchEditorImperatives($0) }
    }

    private func determineIfScratchBasedEditor(completion: @escaping (Bool) -> Void) {
        guard webView != nil else {
            LogNotify.error("WebView is nil. This should not happen.")
            return
        }
        let condition = "document.getElementById('scratch-link-extension-script') != null"

        webView!.evaluateJavaScript(condition) { (result, error) in
            let isScratchEditor = result as? Bool ?? false
            completion(isScratchEditor)
        }
    }

    private func switchEditorImperatives(_ isScratchEditor: Bool) {
        guard webView != nil else {
            LogNotify.error("WebView is nil. This should not happen.")
            return
        }
        if isScratchEditor {
            LogNotify.log("Switching editor imperatives to handle scratch based editor")
            MatrixConnectionViewModel.instance.dropBLEConnection()
            self.webView!.customUserAgent = nil
            self.webView!.configuration.applicationNameForUserAgent = "Scrub"
            return
        }

        LogNotify.log("Switching editor imperatives to handle non-scratch based editor")
        self.webView!.configuration.applicationNameForUserAgent = nil
        self.webView!.customUserAgent =
            traitCollection.userInterfaceIdiom == .pad
            ? "Mozilla/5.0 (iPad; CPU OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1"
            : nil
        MatrixConnectionViewModel.instance.restartFromBLEConnectionDrop()
    }
}

extension EditorWebView {

    //MARK: uploading

    private func upload(result download: EditorDownload) {
        guard webView != nil else {
            LogNotify.error("WebView is nil. This should not happen.")
            return
        }
        self.webView!.evaluateJavaScript(filenameQuery) { (result, error) in
            let filename = "\(result ?? "no-project-name")"
            do {
                guard let file = try HexFileManager.store(name: filename, data: download.url.asData(), isHexFile: download.isHex) else {
                    return
                }
                self.uploadFirmware(file) {
                    MatrixConnectionViewModel.instance.connect()
                }
            } catch {
                LogNotify.log(error.localizedDescription)
            }
        }
    }

    private func saveFile(filename: String, data: Data, path: URL? = nil) -> (Bool, Error?) {
        let pathToUse = (path ?? downloadsPath)
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: pathToUse.path) {
                do {
                    try fm.createDirectory(at: pathToUse, withIntermediateDirectories: true)
                } catch {
                    // don't recurse into fallback mode
                    if pathToUse != documentsPath {
                        return saveFile(filename: filename, data: data, path: documentsPath)
                    }
                }
            }
            try data.write(to: pathToUse.appendingPathComponent(filename))
        } catch {
            LogNotify.log("saveFile error: \(error.localizedDescription)")
            return (false, error)
        }

        return (true, nil)
    }

    private func export(download: EditorDownload) {
        do {
            let xml = try download.url.asData()
            let (success, error) = saveFile(filename: "\(download.name).xml", data: xml)
            if success {
                let popup = OkAlert(title: NSLocalizedString("Program exported", comment: ""), message: NSLocalizedString("Program exported message", comment: "actual message in translation file"))
                showPopup(popup)
            } else {
                throw error!
            }
        } catch {
            LogNotify.log(error.localizedDescription)
        }
    }

}
