import UIKit
import WebKit

final class EditorViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    //TODO: after ios11 is dropped, make this a LET constant and remove the exclamation mark
    var editor: Editor!

    var webview: WKWebView! //webviews are buggy and cannot be placed via interface builder

    init?(coder: NSCoder, editor: Editor) {
        self.editor = editor
        super.init(coder: coder)
         
    }
    
    required init?(coder: NSCoder) {
        if #available(iOS 13.0, *) {
            fatalError("initWithCoder is not implemented")
        }
        super.init(coder: coder)
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
        
        if #available(iOS 13.0, *), traitCollection.userInterfaceIdiom == .pad {
            // turn this off when microsoft pxt and nepo can handle the new useragent of iOS13
            // i.e. they check in a different way for the browser type,
            // e.g. as suggested on https://51degrees.com/blog/missing-ipad-tablet-web-traffic
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
			upload(result: download)
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
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
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

    private func upload(result download: EditorDownload) {
        do {
            DispatchQueue.main.async {
                HexFileStoreDialog.showStoreHexUI(controller: self, hexFile: download.url) { error in
                    //TODO: some reaction
                } saveCompleted: { file in
                    FirmwareUpload.uploadWithoutConfirmation(controller: self, program: file, partialFlashing: true) {
                        MatrixConnectionViewController.instance.connect()
                    }
                }
            }
        }
    }
}

