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
    let alertPublisher: Alertable

    var body: some View {
        EditorWebViewRepresentable(editor: editor, alertPublisher: alertPublisher, uploadFirmware: FirmwareUploadSwiftUI.uploadWithoutConfirmation)
            .background(DisableSwipeBackGestureView())
    }
}

private struct DisableSwipeBackGestureView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DisableSwipeBackViewController {
        DisableSwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: DisableSwipeBackViewController, context: Context) {}
}

private class DisableSwipeBackViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        if #available(iOS 26.0, *) {
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = false
        }
    }
}

struct EditorWebViewRepresentable: UIViewRepresentable {
    let editor: Editor
    let alertPublisher: Alertable
    let uploadFirmware: (_ alertPublisher: Alertable, _ program: HexFile, _ completion: (() -> Void)?) -> Void

    func makeUIView(context: Context) -> EditorWebView {
        return EditorWebView(frame: .zero, alertPublisher: alertPublisher, uploadFirmware: uploadFirmware)
    }

    func updateUIView(_ editorWebView: EditorWebView, context: Context) {
        // Only reload the webview, when the url has changed
        guard editorWebView.editor?.url != editor.url else { return }
        editorWebView.load(editor: editor)
    }
}

final class EditorWebView: UIView {
    var webView: WKWebView?
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    var editor: Editor?
    let alertPublisher: Alertable
    let uploadFirmware: (_ alertPublisher: Alertable, _ program: HexFile, _ completion: (() -> Void)?) -> Void

/* Changes from master
    var webview: WKWebView!  //webviews are buggy and cannot be placed via interface builder
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!

    var editor: Editor?
    /// Native-proxy bridge for the Calliope Campus editor. Non-nil only
    /// when `editor is CampusBridgedEditor` — keeps the legacy editors on the
    /// download-capture path and routes Campus's BLE/flash/GATT through
    /// the WKScriptMessageHandler.
    private var proxyMessageHandler: CalliopeProxyMessageHandler?
*/
    private var latestDownloadedTargetFile: URL?

    /// Retained while the "where do you want to save this?" dialog for a
    /// non-hex editor download is on screen, so its delegate stays alive.
    private var savePickerInstance: UIDocumentPickerViewController?
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
        alertPublisher: Alertable,
        uploadFirmware: @escaping (_ alertPublisher: Alertable, _ program: HexFile, _ completion: (() -> Void)?) -> Void
    ) {
        self.alertPublisher = alertPublisher
        self.uploadFirmware = uploadFirmware
        super.init(frame: frame)
        setupLoadingIndicator()
        webView = setupWebView()
        scratchLink.setup(webView: webView!)
        scratchLink.delegate = self
    }

    required init?(coder: NSCoder) {
        self.alertPublisher = TestAlertable()
        self.uploadFirmware = { alertPublisher, program, completion in }
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

/* Changes from master
        let controller = WKUserContentController()

        #if DEBUG
        WebLogHandler().register(with: controller, WebLogHandler.ALL_LEVELS)
        #endif
*/
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .video
        // Enable persistent caching for offline support
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = Styles.colorWhite

        webView.navigationDelegate = self
        webView.uiDelegate = self
/* Changes from master
        // For every Calliope Campus editor (the campus home and its /blocks,
        // /makecode and /python flavours — anything conforming to
        // `CampusBridgedEditor`), register the native-proxy bridge as the
        // `calliope` script-message handler BEFORE the page loads. The widget's
        // detection probe (`window.webkit?.messageHandlers?.calliope`) needs
        // this present at script start.
        //
        // Important: use `webview.configuration.userContentController` —
        // the LIVE controller — not the local `controller` variable.
        // WKWebView makes its own copy of WKWebViewConfiguration when
        // created (Apple docs), so modifying the original-config's
        // controller after WKWebView init has NO EFFECT on the actual
        // running webview. The local-controller path was the bug behind
        // the widget showing "Browser nicht unterstützt": the handler
        // got attached to an unused controller and the JS never saw
        // `window.webkit.messageHandlers.calliope`, so isNativeMode()
        // returned false and the widget fell back to web-mode
        // (where iOS WKWebView has neither WebUSB nor Web Bluetooth →
        // status = unsupported). Same pattern used by the working
        // WBWebView reference impl.
        if editor is CampusBridgedEditor {
            let handler = CalliopeProxyMessageHandler(webView: webview)
            self.proxyMessageHandler = handler
            webview.configuration.userContentController.add(
                handler,
                name: CalliopeProxyMessageHandler.handlerName
            )
        }

        webview.navigationDelegate = self
        webview.uiDelegate = self
        webview.backgroundColor = Styles.colorWhite
 */

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
/* Changes from master
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Hide the tab bar to provide more screen space for the editor
        self.tabBarController?.tabBar.isHidden = true

        // Disable all navigation gestures to prevent interference with web view content
        disableNavigationGestures()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Show the tab bar again when leaving the editor
        self.tabBarController?.tabBar.isHidden = false

        MatrixConnectionViewController.instance.restartFromBLEConnectionDrop()

        // Tear down the proxy bridge — WKUserContentController retains
        // script-message handlers strongly, so without an explicit remove
        // the handler (and its captured BLE notify subscriptions) would
        // outlive the editor.
        if proxyMessageHandler != nil {
            webview?.configuration.userContentController.removeScriptMessageHandler(
                forName: CalliopeProxyMessageHandler.handlerName
            )
            proxyMessageHandler = nil
        }

        // Re-enable navigation gestures
        enableNavigationGestures()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Ensure gestures remain disabled after view fully appears
        // This catches any gestures that might be re-added during transitions
        disableNavigationGestures()
    }

    // MARK: - Gesture Management

    private func disableNavigationGestures() {
        // Disable the standard interactive pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = true

        // Disable edge pan gestures and any pan gestures on the navigation controller's view
        // This prevents fluid navigation from interfering with web view content
        if let gestures = navigationController?.view.gestureRecognizers {
            for gesture in gestures {
                if gesture is UIScreenEdgePanGestureRecognizer || gesture is UIPanGestureRecognizer {
                    gesture.isEnabled = false
                }
            }
        }

        // Also configure the webview's scroll view pan gesture to not delay touches
        if let panGesture = webview?.scrollView.panGestureRecognizer {
            panGesture.delaysTouchesBegan = false
            panGesture.delaysTouchesEnded = false
        }
    }

    private func enableNavigationGestures() {
        // Re-enable the standard interactive pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        // Re-enable gestures on the navigation controller's view
        if let gestures = navigationController?.view.gestureRecognizers {
            for gesture in gestures {
                if gesture is UIScreenEdgePanGestureRecognizer || gesture is UIPanGestureRecognizer {
                    gesture.isEnabled = true
                }
            }
        }
    }
    
*/
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
       
/* Changes from master
        // Any editor may hand us a download — the Python editor saving a .py, the
        // Blocks editor a .sb3, Arcade an image. Restricting this to two editors
        // is what made "save" do nothing in the others.
        //
        // `blob:` needs the same treatment even though WebKit does NOT set
        // `shouldPerformDownload` for it: the campus editors build their save
        // files in memory and navigate to a blob URL, which used to fall through
        // to `.allow` — the web view then navigated nowhere and saving looked
        // like the app was blocking it. Turning the navigation into a download
        // lets WebKit resolve the blob for us.
        if navigationAction.shouldPerformDownload || editor.isBlob(request.url ?? URL(fileURLWithPath: "/")) {
 */
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
        let alert = AppAlert.ok(title: message, completion: completionHandler)
        alertPublisher.alert = alert
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = AppAlert(
            title: message,
            actions: [
                StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: { completionHandler(true) }),
                StandardAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { completionHandler(false) }),
            ]
        )
        alertPublisher.alert = alert
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = AppAlert(
            title: prompt,
            textField: .init(
                hint: "Program Name",
                defaultValue: "",
                actions: [
                    TextFieldAlertAction(
                        NSLocalizedString("OK", comment: ""),
                        handler: { input in
                            completionHandler(input)
                        }
                    ),
                    TextFieldAlertAction(
                        NSLocalizedString("Cancel", comment: ""),
                        handler: { input in
                            completionHandler(nil)
                        }
                    ),
                ]
            )
        )
        alertPublisher.alert = alert
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
/* Changes from master
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        // Accept downloads from EVERY editor. The previous editor allow-list left
        // `completionHandler` uncalled for the others, which is what made saving
        // from an editor look like the app was blocking it: WebKit waits for a
        // destination that never arrives. What happens with the file afterwards is
        // decided by its type in `downloadDidFinish`.
        guard let target = prepareTemporaryStorage(for: suggestedFilename) else {
            completionHandler(nil)
            return
        }

        latestDownloadedTargetFile = target
        try? FileManager.default.removeItem(at: target)
        completionHandler(target)
 */
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = latestDownloadedTargetFile else {
            return
        }
        
/* Changes from master
        guard let fileextension = FileExtension(rawValue: url.pathExtension.lowercased()) else {
            // Unknown or missing extension (blob downloads sometimes arrive
            // without one). Don't drop the file — let the user save it.
            LogNotify.log("Downloaded file \(url.lastPathComponent) has no known extension - offering to save it")
            presentSaveDialog(for: url)
            return
        }
 */

        switch fileextension {
        case .hex:
            // Keep a copy in the programs list before flashing — the download
            // itself only lives in the temporary directory, which is why hex
            // files from MicroPython, Campus and Arcade never appeared there.
            storeDownloadedProgram(from: url, fileExtension: .hex)
            uploadHex(from: url)
        case .py, .sb3, .png:
            // A Python source, a Blocks project or an Arcade image is a user
            // document, not a program for the mini: let the user pick where it
            // goes (the "Calliope mini" folder, the iCloud "Calliope mini App"
            // folder, or anywhere else).
            presentSaveDialog(for: url)
        case .html, .json:
            storeSessionData(for: url)
        }

/* Changes from master
    }

    /// Copies a finished download into the programs directory so it shows up in
    /// "Editors and Programs". Best effort: a failure here must not stop a flash.
    private func storeDownloadedProgram(from location: URL, fileExtension: FileExtension) {
        let name = location.deletingPathExtension().lastPathComponent
        do {
            let data = try Data(contentsOf: location)
            _ = try HexFileManager.store(name: name, data: data, fileExtension: fileExtension)
            LogNotify.log("Stored downloaded \(fileExtension.rawValue) file as program \(name)")
        } catch {
            LogNotify.log("Could not store downloaded \(fileExtension.rawValue) file: \(error.localizedDescription)")
        }
    }

    /// Hands a downloaded file to the system save dialog so the user chooses the
    /// destination. The temporary copy is removed once the dialog is done.
    private func presentSaveDialog(for location: URL) {
        LogNotify.log("Offering \(location.lastPathComponent) for saving")
        let picker = UIDocumentPickerViewController(forExporting: [location], asCopy: true)
        picker.delegate = self
        picker.shouldShowFileExtensions = true
        savePickerInstance = picker
        present(picker, animated: true)
 */
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
        uploadFirmware(alertPublisher, file) {
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
            let documentsDir = try StorageDirectory.shared.documentsDirectory()
            let destination = documentsDir.appendingPathComponent(location.lastPathComponent)
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

        let alert = AppAlert.ok(title: message, completion: {})
        alertPublisher.alert = alert

    }
}

extension EditorWebView: ScratchLinkDelegate {

/* Changes from master
// MARK: - Save dialog for non-hex editor downloads

extension EditorViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard controller === savePickerInstance else { return }
        LogNotify.log("Saved editor file to \(urls.first?.path ?? "<unknown>")")
        savePickerInstance = nil
        // Do NOT delete the staged file here. `asCopy: true` hands the copy to the
        // file provider, which may still be reading the source when this callback
        // arrives — deleting it made the copy fail with "the file does not exist".
        // Just drop our reference; the staged file lives in the temporary
        // directory (the system reclaims it, and the next download overwrites it).
        latestDownloadedTargetFile = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard controller === savePickerInstance else { return }
        LogNotify.log("Saving editor file cancelled")
        savePickerInstance = nil
        clearTemporaryStorage()
    }
}

extension EditorViewController: ScratchLinkDelegate {
    
*/
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
/*
        // Campus is Scratch-based (it loads the scratch-link extension script),
        // but it does NOT drive BLE through ScratchLink — it goes through the
        // native-proxy bridge, which reads the app's own usageReadyCalliope.
        // Running the scratch branch here would call dropBLEConnection() and
        // tear down exactly the connection the bridge needs (plus set
        // isInBackground, which suppresses the app's auto-reconnect), so the
        // editor came up disconnected until the user hit the connect icon.
        // Skipping is safe: the non-scratch branch would only re-apply the
        // user-agent values viewDidLoad already set for Campus.
        //
        // This matters most for the campus /blocks flavour: it IS a scratch
        // editor by the probe's definition (the scratch-link script tag is
        // present), so without widening this gate to every CampusBridgedEditor
        // it would take the scratch branch and drop the very BLE connection the
        // bridge is built on.
        if editor is CampusBridgedEditor {
            return
        }
        determineIfScratchBasedEditor() { self.switchEditorImperatives($0)}
*/
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
/* Changes from master
    
    /// Writes the freshly downloaded hex into the app's temporary directory and
    /// returns it as a `HexFile`, so the transfer to the Calliope mini reads from
    /// local storage instead of the program library (which is iCloud-backed on a
    /// Shared iPad).
    ///
    /// Returns `nil` when the local copy could not be written; the caller then
    /// falls back to the stored program.
    private static func localFlashCopy(of data: Data, named name: String) -> HexFile? {
        sweepStaleFlashCopies()

        // Keep the project name, but make sure it cannot break the path.
        let safeName = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-flash-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent(safeName + ".hex")

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url)
            LogNotify.log("Editor download: transferring from local copy (\(data.count) bytes)")
            return HexFile(url: url, name: name, date: Date())
        } catch {
            LogNotify.log("Editor download: could not write local copy (\(error.localizedDescription)) - using the stored program instead")
            try? FileManager.default.removeItem(at: directory)
            return nil
        }
    }

    /// Removes local flash copies left over from earlier downloads.
    private static func sweepStaleFlashCopies() {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: fileManager.temporaryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return }

        let cutoff = Date().addingTimeInterval(-600)   // older than 10 minutes
        for entry in entries where entry.lastPathComponent.hasPrefix("editor-flash-") {
            let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified, modified > cutoff { continue }
            try? fileManager.removeItem(at: entry)
        }
    }
*/
    
    private func upload(result download: EditorDownload) {
        guard webView != nil else {
            LogNotify.error("WebView is nil. This should not happen.")
            return
        }
        self.webView!.evaluateJavaScript(filenameQuery) { (result, error) in
            let filename = "\(result ?? "no-project-name")"
            do {
                let data = try download.url.asData()

                // Not a hex (e.g. an image saved out of Arcade): there is nothing
                // to flash, so ask where to save it instead of quietly dropping a
                // file into the programs folder.
                guard download.isHex else {
                    self.offerSaveOfEditorFile(named: filename, data: data, fileExtension: .png)
                    return
                }
                self.uploadFirmware(self.alertPublisher, file) {
                    MatrixConnectionViewModel.instance.connect()
/* Changes from master

                guard let file = try HexFileManager.store(name: filename, data: data, isHexFile: true) else {
                    return
                }

                // Transfer from a LOCAL copy of the freshly downloaded bytes,
                // never from the stored program itself. On a Shared iPad the
                // program library lives in the iCloud container, and reading a
                // hex back from there while copying to the Calliope mini has
                // proven unreliable — DAPLink then reports a checksum failure.
                // The library copy above is still written first, so the program
                // is never lost, even if the transfer is cancelled.
                let flashSource = EditorViewController.localFlashCopy(of: data, named: filename) ?? file

                FirmwareUpload.uploadWithoutConfirmation(controller: self, program: flashSource) {
                    MatrixConnectionViewController.instance.connect()
 */
                }
            } catch {
                LogNotify.log(error.localizedDescription)
            }
        }
    }

    /// Stages editor data under a sensible filename and opens the save dialog.
    private func offerSaveOfEditorFile(named name: String, data: Data, fileExtension: FileExtension) {
        guard let staged = prepareTemporaryStorage(for: "\(name).\(fileExtension.rawValue)") else {
            return
        }
        do {
            try? FileManager.default.removeItem(at: staged)
            try data.write(to: staged)
            latestDownloadedTargetFile = staged
            presentSaveDialog(for: staged)
        } catch {
            LogNotify.log("Could not stage \(fileExtension.rawValue) file for saving: \(error.localizedDescription)")
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
                let alert = AppAlert.ok(
                    title: NSLocalizedString("Program exported", comment: ""),
                    message: NSLocalizedString("Program exported message", comment: "actual message in translation file"),
                    completion: {}
                )
                alertPublisher.alert = alert
            } else {
                throw error!
            }
        } catch {
            LogNotify.log(error.localizedDescription)
        }
    }

}
