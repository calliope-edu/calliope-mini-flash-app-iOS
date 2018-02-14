import UIKit
import WebKit

final class HelpViewController: BaseViewController {

    public var html = ""

    //private let textView = UITextView()
    private let textView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "help.title".localized
        view.backgroundColor = Styles.colorWhite

        let fontSize = range(30...40)
        let margin = range(20...40)

        let style = String(format:"""
            <style type=\"text/css\">
              @font-face {
                font-family: 'Roboto Mono'; src: url('RobotoMono-Bold.ttf');
              }
              body {
                font-size: %1.0fpx;
                margin: %1.0fpx;
                font-family: 'Roboto Mono';
              }
            </style>
            """, fontSize, margin)
        view.addSubview(textView)
        // textView.attributedText = attributed(html: style + html)
        textView.loadHTMLString(style+html, baseURL: NSURL.fileURL(withPath: Bundle.main.bundlePath))

        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func attributed(html:String) -> NSAttributedString? {

        guard let data = html.data(using: .utf8, allowLossyConversion: false) else { return nil }

        do {
            return try NSAttributedString(data: data, options: [
                NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html
            ], documentAttributes: nil)
        } catch {
            return nil
        }
    }
}
