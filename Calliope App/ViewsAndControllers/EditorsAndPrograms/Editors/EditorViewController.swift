import UIKit
import WebKit

import ScratchLinkKit

final class EditorViewController: UIViewController {

    var webview: WKWebView!  //webviews are buggy and cannot be placed via interface builder
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    var editor: Editor?
    private var latestDownloadedTargetFile: URL?
    var documentsPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var downloadsPath: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }
    
    private let scratchLink = ScratchLink()
    
    let filenameQuery = "document.querySelector('input#fileNameInput2').value"
    
    init?(coder: NSCoder, editor: Editor) {
        self.editor = editor
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let editor = editor, let url = editor.url else {
            LogNotify.log("No editor or empty URL -- bailing")
            return
        }

        navigationItem.title = editor.name
        view.backgroundColor = Styles.colorWhite

        let controller = WKUserContentController()
        
        #if DEBUG
        WebLogHandler().register(with: controller, WebLogHandler.ALL_LEVELS)
        #endif
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.mediaTypesRequiringUserActionForPlayback = .video
        
        
        webview = WKWebView(frame: self.view.bounds, configuration: configuration)
        webview.translatesAutoresizingMaskIntoConstraints = false

        webview.navigationDelegate = self
        webview.uiDelegate = self
        webview.backgroundColor = Styles.colorWhite

        // Configure scroll view to better handle touches in web content
        // This helps with selecting items in MakeCode project lists
        webview.scrollView.delaysContentTouches = false
        webview.scrollView.canCancelContentTouches = true

        self.view.insertSubview(webview, at: 0)
        let bounds: UILayoutGuide = self.view.safeAreaLayoutGuide
        webview.topAnchor.constraint(equalTo: bounds.topAnchor).isActive = true
        webview.bottomAnchor.constraint(equalTo: bounds.bottomAnchor).isActive = true
        webview.leftAnchor.constraint(equalTo: bounds.leftAnchor).isActive = true
        webview.rightAnchor.constraint(equalTo: bounds.rightAnchor).isActive = true

        scratchLink.setup(webView: self.webview)
        scratchLink.delegate = self
        
        loadingIndicator.startAnimating()
        webview.configuration.applicationNameForUserAgent = editor is BlocksMiniEditor ? "Scrub" : nil
        webview.customUserAgent = traitCollection.userInterfaceIdiom == .pad && !(editor is BlocksMiniEditor) ? "Mozilla/5.0 (iPad; CPU OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1" : nil
        self.webview?.load(URLRequest(url: url))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)

        // Disable all navigation gestures to prevent interference with web view content
        disableNavigationGestures()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MatrixConnectionViewController.instance.restartFromBLEConnectionDrop()

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
    
}

extension EditorViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let editor = editor else {
            return
        }

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
        loadingIndicator.stopAnimating()
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

extension EditorViewController: WKUIDelegate {
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

extension EditorViewController: WKDownloadDelegate {
    
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
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
        FirmwareUpload.uploadWithoutConfirmation(controller: self, program: file) {
            MatrixConnectionViewController.instance.connect()
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

extension EditorViewController: ScratchLinkDelegate {
    
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

extension EditorViewController {
    // MARK: Handle possible editor change (i.e. Scratch Based with own BLE connection)
    
    private func handlePossibleEditorChanges() {
        determineIfScratchBasedEditor() { self.switchEditorImperatives($0)}
    }
    
    
    private func determineIfScratchBasedEditor(completion: @escaping (Bool) -> Void) {
        let condition = "document.getElementById('scratch-link-extension-script') != null"
        
        webview.evaluateJavaScript(condition) { (result, error) in
            let isScratchEditor = result as? Bool ?? false
            completion(isScratchEditor)
        }
    }
    
    private func switchEditorImperatives(_ isScratchEditor: Bool) {
        if (isScratchEditor) {
            LogNotify.log("Switching editor imperatives to handle scratch based editor")
            MatrixConnectionViewController.instance.dropBLEConnection()
            self.webview.customUserAgent = nil
            self.webview.configuration.applicationNameForUserAgent = "Scrub"
            return
        }
        
        LogNotify.log("Switching editor imperatives to handle non-scratch based editor")
        self.webview.configuration.applicationNameForUserAgent = nil
        self.webview.customUserAgent = traitCollection.userInterfaceIdiom == .pad ? "Mozilla/5.0 (iPad; CPU OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1" : nil
        MatrixConnectionViewController.instance.restartFromBLEConnectionDrop()
    }
}


extension EditorViewController {
    
    //MARK: uploading
    
    private func upload(result download: EditorDownload) {
        self.webview.evaluateJavaScript(filenameQuery) { (result, error) in
            let filename = "\(result ?? "no-project-name")"
            do {
                guard let file = try HexFileManager.store(name: filename, data: download.url.asData(), isHexFile: download.isHex) else {
                    return
                }
                FirmwareUpload.uploadWithoutConfirmation(controller: self, program: file) {
                    MatrixConnectionViewController.instance.connect()
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
                let alert = UIAlertController(
                    title: NSLocalizedString("Program exported", comment: ""),
                    message: NSLocalizedString("Program exported message", comment: "actual message in translation file"),
                    preferredStyle: .alert)

                alert.addAction(
                    UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .destructive) { _ in
                    })

                self.present(alert, animated: true)
            } else {
                throw error!
            }
        } catch {
            LogNotify.log(error.localizedDescription)
        }
    }

}
