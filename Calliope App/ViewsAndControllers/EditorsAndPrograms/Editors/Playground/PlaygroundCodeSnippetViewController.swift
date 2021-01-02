//
//  PlaygroundCodeSnippetViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.01.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit
import Highlightr

protocol CodeSnippetController: UIViewController {
    var codeSnippet: CodeSnippet? { get set }
}

class PlaygroundCodeSnippetViewController: UIViewController, CodeSnippetController {

    var codeSnippet: CodeSnippet? {
        didSet {
            loadViewIfNeeded()
            title = codeSnippet?.title


            guard let snippetContent = codeSnippet?.content,
                  let code = NSMutableString(utf8String: snippetContent) else {
                codeView.text = ""
                return
            }

            if let regex = try? NSRegularExpression(pattern: "\\<\\#T\\#\\#.*?\\#\\#(.*?)\\#\\>", options: []) {
                let replaced: Int = regex.replaceMatches(in: code, options: [], range: NSMakeRange(0, code.length), withTemplate: "$1")
            }

            if let regex = try? NSRegularExpression(pattern: "\\<\\#(.*?)\\#\\>") {
                let replaced: Int = regex.replaceMatches(in: code, options: [], range: NSMakeRange(0, code.length), withTemplate: "$1")
            }

            guard let highlightr = Highlightr() else {
                codeView.text = String(code)
                return
            }

            highlightr.setTheme(to: "xcode")
            //highlightr.setTheme(to: "school-book")
            let highlightedCode = highlightr.highlight(String(code), as: "swift")
            codeView.attributedText = highlightedCode
        }
    }

    @IBOutlet weak var codeView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
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
