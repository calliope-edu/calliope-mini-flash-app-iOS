//
//  PlaygroundCodeSnippetViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.01.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit
import Highlightr
import MobileCoreServices

protocol CodeSnippetController: UIViewController {
    var codeSnippet: CodeSnippet? { get set }
}

class PlaygroundCodeSnippetViewController: UIViewController, CodeSnippetController, UIDragInteractionDelegate, UIDropInteractionDelegate {


    var codeSnippet: CodeSnippet? {
        didSet {
            loadViewIfNeeded()
            title = codeSnippet?.title


            guard let snippetContent = codeSnippet?.content,
                  let code = NSMutableString(utf8String: snippetContent) else {
                codeView.text = ""
                return
            }

            let highlightedCode = codeSnippetContentToAttributedString(code)

            codeView.attributedText = highlightedCode
        }
    }

    let regularCodeFont = Styles.scaledFont(Styles.defaultRegularFont(size: 16, mono: true), for: .body)
    let boldCodeFont = Styles.scaledFont(Styles.defaultBoldFont(size: 16, mono: true), for: .body)

    func codeSnippetContentToAttributedString(_ code: NSMutableString) -> NSAttributedString {
        guard let highlightr = Highlightr() else {
            //highlightr does not work for some reason
            LogNotify.log("highlightr could not be instanciated")
            //replace placeholders with content to avoid badly looking code
            if let regex = try? NSRegularExpression(pattern: "\\<\\#T\\#\\#.*?\\#\\#(.*?)\\#\\>", options: []) {
                regex.replaceMatches(in: code, options: [], range: NSMakeRange(0, code.length), withTemplate: "$1")
            }
            if let regex = try? NSRegularExpression(pattern: "\\<\\#(.*?)\\#\\>") {
                //replace with the second pattern part here, which is what you would get on pressing enter
                regex.replaceMatches(in: code, options: [], range: NSMakeRange(0, code.length), withTemplate: "$1")
            }
            let attributed = NSMutableAttributedString(string: code as String)
            attributed.addAttribute(.font, value: regularCodeFont, range: NSMakeRange(0, code.length))
            return attributed
        }


        //replace placeholders with different markers to avoid parser confusion
        if let regex = try? NSRegularExpression(pattern: "\\<\\#T\\#\\#(.*?)\\#\\#.*?\\#\\>", options: []) {
            regex.replaceMatches(in: code, options: [], range: NSMakeRange(0, code.length), withTemplate: "___$1___")
        }

        if let regex = try? NSRegularExpression(pattern: "\\<\\#(.*?)\\#\\>") {
            //replace with the first pattern part here, because it will later be highlighted as placeholder
            regex.replaceMatches(in: code, options: [], range: NSMakeRange(0, code.length), withTemplate: "___$1___")
        }

        highlightr.setTheme(to: "xcode")
        //highlightr.setTheme(to: "school-book")
        highlightr.theme.boldCodeFont = boldCodeFont
        highlightr.theme.codeFont = regularCodeFont

        let highlightedCode = NSMutableAttributedString(attributedString: highlightr.highlight(String(code), as: "swift") ?? NSAttributedString())

        //set style of marked areas to indicate that there will be a replacement
        if let regex = try? NSRegularExpression(pattern: "___.*?___", options: []) {
            let matches = regex.matches(in: highlightedCode.string, options: [], range: NSMakeRange(0, code.length)).reversed()
            for match in matches {
                let range = match.range
                highlightedCode.addAttribute(.backgroundColor, value: UIColor.gray, range: match.range)
                highlightedCode.deleteCharacters(in: NSMakeRange(range.upperBound - 3, 3))
                highlightedCode.deleteCharacters(in: NSMakeRange(range.lowerBound, 3))
            }
        }
        return highlightedCode
    }

    @IBOutlet weak var codeView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let copyAction = UILongPressGestureRecognizer()
        copyAction.minimumPressDuration = 1.0
        copyAction.addTarget(self, action: #selector(copyCode(_:)))
        self.view.addGestureRecognizer(copyAction)
        self.view.addInteraction(UIDragInteraction(delegate: self))
    }

    @objc func copyCode(_ sender: Any) {
        guard let codeSnippet = codeSnippet,
              ((sender as? UIGestureRecognizer)?.state ?? .began) == .began else {
            return
        }
        UIPasteboard.general.string = codeSnippet.content
        let notificationContent = UNMutableNotificationContent()
        notificationContent.body = "Code snippet copied to clipboard".localized
        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let notificationRequest = UNNotificationRequest(identifier: "calliope-copied-playground-snippet", content: notificationContent, trigger: notificationTrigger)
        UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: nil)
    }


    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        guard let codeSnippet = codeSnippet, let data = codeSnippet.content.data(using: .utf8) else {
            return []
        }
        let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: kUTTypeUTF8PlainText as String)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
