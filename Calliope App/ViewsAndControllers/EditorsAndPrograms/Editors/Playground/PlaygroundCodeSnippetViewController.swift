//
//  PlaygroundCodeSnippetViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.01.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

protocol CodeSnippetController: UIViewController {
    var codeSnippet: CodeSnippet? { get set }
}

class PlaygroundCodeSnippetViewController: UIViewController, CodeSnippetController {

    var codeSnippet: CodeSnippet? {
        didSet {
            loadViewIfNeeded()
            codeView.text = codeSnippet?.content
            title = codeSnippet?.title
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
