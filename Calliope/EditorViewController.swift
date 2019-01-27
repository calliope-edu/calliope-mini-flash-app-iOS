import UIKit
import WebKit

final class EditorViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    public var editor: Editor!

    private var webview: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = editor.name
        view.backgroundColor = Styles.colorWhite

        addHelpButton()
        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller;
        let webView = WKWebView(frame:self.view.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.backgroundColor = Styles.colorWhite
        self.view.addSubview(webView)
        self.webview = webView

        guard let url = editor.url else {
            LOG("URL is empty!)")
            return
        }
        LOG("loading \(url)")

        webView.load(URLRequest(url: url))

        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        LOG("policy for action \(navigationAction.request.url?.absoluteString.truncate(length: 100) ?? "")")

        if let download = editor.download(navigationAction.request) {

            decisionHandler(.cancel)

            guard let device = Device.current else {

                LOG("no target device selected")

                let alert = UIAlertController(
                    title: "No Device",
                    message: "Please connect a device first",
                    preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(
                    title: "OK",
                    style: UIAlertAction.Style.default,
                    handler: nil))
                present(alert, animated: true, completion: nil)

                return
            }

            DispatchQueue.global().async {
                do {
                    LOG("downloaded: start - \(download.url.absoluteString.truncate(length: 60))")
                    let data = try Data(contentsOf: download.url)
                    LOG("downloaded: stop \(data.count)")

                    let file = try HexFileManager.store(name: download.name, data: data)

                    DispatchQueue.main.async {

                        let vc = UploadViewConroller()
                        vc.file = file
                        vc.uuid = device.identifier
                        vc.buttonPressAction = { state in

                            switch(state) {
                            case .progress:
                                print("aborted")
                            case .success:
                                print("success")
                            case .error:
                                print("error")
                            }

                        }
                        let nc = UINavigationController(rootViewController: vc)
                        nc.modalTransitionStyle = .coverVertical
                        self.present(nc, animated: true)

                    }

                } catch {
                    ERR(error)
                }
            }

        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // LOG("policy for response \(String(describing: navigationResponse.response.url))")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        // LOG("finish")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        LOG(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        LOG(error)
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

}

