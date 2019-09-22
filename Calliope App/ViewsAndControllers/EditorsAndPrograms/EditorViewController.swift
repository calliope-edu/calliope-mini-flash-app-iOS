import UIKit
import WebKit

final class EditorViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    public var editor: Editor!

    private var webview: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = editor.name
        view.backgroundColor = Styles.colorWhite

        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller;
        let webView = WKWebView(frame:self.view.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.backgroundColor = Styles.colorWhite
        self.view.insertSubview(webView, at: 0)
        self.webview = webView

        guard let url = editor.url else {
            LogNotify.log("URL is empty!)")
            return
        }
        LogNotify.log("loading \(url)")

        loadingIndicator.startAnimating()
        webView.load(URLRequest(url: url))

        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.navigationController?.setNavigationBarHidden(false, animated: animated)
	}

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        LogNotify.log("policy for action \(navigationAction.request.url?.absoluteString.truncate(length: 100) ?? "")")

        if let download = editor.download(navigationAction.request) {
            decisionHandler(.cancel)
			upload(result: download)
        } else if navigationAction.request.url?.absoluteString == "https://calliope.cc/" {
			decisionHandler(.cancel)
			self.navigationController?.popViewController(animated: true)
		} else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // LOG("policy for response \(String(describing: navigationResponse.response.url))")
        decisionHandler(.allow)
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
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            completionHandler()
        }))

        present(alertController, animated: true, completion: nil)
    }


    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "alert.ok".localized, style: .default, handler: { (action) in
            completionHandler(true)
        }))

        alertController.addAction(UIAlertAction(title: "alert.cancel".localized, style: .default, handler: { (action) in
            completionHandler(false)
        }))

        present(alertController, animated: true, completion: nil)
    }


    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {

        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.text = defaultText
        }

        alertController.addAction(UIAlertAction(title: "alert.ok".localized, style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))

        alertController.addAction(UIAlertAction(title: "alert.cancel".localized, style: .default, handler: { (action) in
            completionHandler(nil)
        }))

        present(alertController, animated: true, completion: nil)
    }

	//MARK: uploading

	private func upload(result download: EditorDownload) {
		DispatchQueue.global().async {
			do {
				LogNotify.log("downloaded: start - \(download.url.absoluteString.truncate(length: 60))")
				let data = try Data(contentsOf: download.url)
				LogNotify.log("downloaded: stop \(data.count)")

				DispatchQueue.main.async {
					do {
						let file = try HexFileManager.store(name: download.name, data: data)

						let controller = UIAlertController(title: "Downloaded Program", message: nil, preferredStyle: .alert)
						controller.addAction(UIAlertAction(title: "Upload", style: .default, handler: { (_) in
							let uploader = FirmwareUpload()
							self.present(uploader.alertView, animated: true) {
								uploader.upload(file: file) {
									self.dismiss(animated: true, completion: nil)
								}
							}
						}))
						controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))

						DispatchQueue.main.async {
							self.present(controller, animated: true, completion: nil)
						}
					}
					catch {
						LogNotify.log("\(error)")
					}
				}
			}
			catch {
				LogNotify.log("\(error)")
			}
		}

	}

}

