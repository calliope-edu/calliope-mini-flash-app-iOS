//
//  HelpContentViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.08.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

extension UIView {
    func localizeTextViews(_ translationTableName: String) {
        for view in self.subviews {
            if let textView = view as? UITextView {
                if let identifier = textView.restorationIdentifier {
                    let localizationIdentifier = identifier + ".text"
                    textView.text = NSLocalizedString(localizationIdentifier,
                                                      tableName: translationTableName, comment: "")
                }
            } else {
                view.localizeTextViews(translationTableName)
            }
        }
    }
}

class HelpContentViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.localizeTextViews("Help")
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let webViewController = segue.destination as? HelpWebViewController else {
            return
        }
        if segue.identifier == "morebluetooth" {
            webViewController.url = URL(string: "https://calliope.cc/programmieren/mobil")
        }
        if segue.identifier == "moreFlash" {
            webViewController.url = URL(string: "https://calliope.cc/start/tipps")
        }
        if segue.identifier == "moreEditors" {
            webViewController.url = URL(string: "https://calliope.cc/programmieren/editoren")
        }
        if segue.identifier == "moreCalliope" {
            webViewController.url = URL(string: "https://calliope.cc")
        }
        if segue.identifier == "morePlayground" {
            webViewController.url = URL(string: "https://calliope.cc/programmieren/playground")
        }
        if segue.identifier == "moreCalliopeMini" {
            webViewController.url = URL(string: "https://calliope.cc/calliope-mini/uebersicht")
        }
    }

}
