import UIKit
import WebKit

final class EditorViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!

    let editor: Editor

    var webview: WKWebView! //webviews are buggy and cannot be placed via interface builder
    lazy var documentsPath: URL = { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }()
    lazy var downloadsPath: URL = { FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0] }()

    init?(coder: NSCoder, editor: Editor) {
        self.editor = editor
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = editor.name
        view.backgroundColor = Styles.colorWhite

        guard let url = editor.url else {
            LogNotify.log("URL is empty!)")
            return
        }
        LogNotify.log("loading \(url)")

        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.mediaTypesRequiringUserActionForPlayback = .video

        webview = WKWebView(frame:self.view.bounds, configuration: configuration)
        webview.translatesAutoresizingMaskIntoConstraints = false

        webview.navigationDelegate = self
        webview.uiDelegate = self
        webview.backgroundColor = Styles.colorWhite

        self.view.insertSubview(webview, at: 0)
        let bounds: UILayoutGuide = self.view.safeAreaLayoutGuide
        webview.topAnchor.constraint(equalTo: bounds.topAnchor).isActive = true
        webview.bottomAnchor.constraint(equalTo: bounds.bottomAnchor).isActive = true
        webview.leftAnchor.constraint(equalTo: bounds.leftAnchor).isActive = true
        webview.rightAnchor.constraint(equalTo: bounds.rightAnchor).isActive = true

        if traitCollection.userInterfaceIdiom == .pad {
            webview.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1"
        }

        loadingIndicator.startAnimating()
        self.webview?.load(URLRequest(url: url))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        LogNotify.log("policy for action \(navigationAction.request.url?.absoluteString.truncate(length: 100) ?? "")")
        let request = navigationAction.request

        if let download = editor.download(request) {
            decisionHandler(.cancel)
            if (download.url.absoluteString.starts(with: "data:text/xml")) {
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
        loadingIndicator.stopAnimating()
        // LOG("finish")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
        LogNotify.log("\(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        LogNotify.log("\(error)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // LOG("terminate")
    }

    //
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
            completionHandler()
        }))

        present(alertController, animated: true, completion: nil)
    }


    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
            completionHandler(true)
        }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .default, handler: { (action) in
            completionHandler(false)
        }))

        present(alertController, animated: true, completion: nil)
    }


    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {

        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.text = defaultText
        }

        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .default, handler: { (action) in
            completionHandler(nil)
        }))

        present(alertController, animated: true, completion: nil)
    }

    //MARK: uploading
    var query = "document.querySelector('input#fileNameInput2').value"
    private func upload(result download: EditorDownload) {
        self.webview.evaluateJavaScript(query) { (result, error) in
            let html = "\(result ?? "no-project-name")" // TODO: Dettermining name and default could be better
            LogNotify.log("html: \(html)")
            do {
                guard let file = try HexFileManager.store(name: html, data: download.url.asData(), isHexFile: download.isHex) else {
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

    private func saveFile(filename: String, data:Data, path:URL? = nil) -> (Bool, Error?) {
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
                let alert = UIAlertController(title: NSLocalizedString("Program exported", comment: ""),
                                              message: NSLocalizedString("Program exported message", comment: "actual message in translation file"),
                                              preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .destructive) {_ in
                })

                self.present(alert, animated: true)
            }
            else {
                throw error!
            }
            /*
             let result = try String(contentsOf: filename)
             LogNotify.log("xml: \(result.count) byte")
             */
        } catch {
            LogNotify.log(error.localizedDescription)
        }
    }

    // Web View Helper

    fileprivate func handleInternalWebView(_ navigationAction: WKNavigationAction, _ webView: WKWebView) -> WKWebView? {
        if let frame = navigationAction.targetFrame {
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
