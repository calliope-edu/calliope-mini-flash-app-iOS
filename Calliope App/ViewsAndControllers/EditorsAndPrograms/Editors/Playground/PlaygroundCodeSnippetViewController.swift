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

    @IBOutlet weak var copySuccessView: UIView!

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
        let copyAction = UILongPressGestureRecognizer()
        copyAction.minimumPressDuration = 1.0
        copyAction.addTarget(self, action: #selector(copyCode(_:)))
        self.view.addGestureRecognizer(copyAction)
        self.view.addInteraction(UIDragInteraction(delegate: self))
    }

    @objc func copyCode(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began, let codeSnippet = codeSnippet else {
            return
        }
        UIPasteboard.general.string = codeSnippet.content
        UIView.animate(withDuration: 0.2) {
            self.copySuccessView.alpha = 1.0
        } completion: { done in
            if done {
                UIView.animateKeyframes(withDuration: 0.2, delay: 1.0) {
                    self.copySuccessView.alpha = 0.0
                }
            }
        }

    }


    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        guard let codeSnippet = codeSnippet, let data = codeSnippet.content.data(using: .utf8) else {
            return []
        }
        let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: kUTTypeUTF8PlainText as String)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }
}
