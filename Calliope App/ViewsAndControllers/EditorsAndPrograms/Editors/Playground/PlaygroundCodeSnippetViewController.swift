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

    private static let codeSnippetHighlighter = SwiftCodeSnippetHighlighter()

    var codeSnippet: CodeSnippet? {
        didSet {
            loadViewIfNeeded()
            title = codeSnippet?.title

            codeView.attributedText = PlaygroundCodeSnippetViewController.codeSnippetHighlighter.codeSnippetToAttributedString(codeSnippet)
        }
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
