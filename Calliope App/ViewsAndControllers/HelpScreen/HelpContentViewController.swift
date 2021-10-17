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
            webViewController.url = URL(string: NSLocalizedString("https://calliope.cc/programmieren/mobil", comment:"URL in Help screen"))
        }
        if segue.identifier == "moreFlash" {
            webViewController.url = URL(string: NSLocalizedString("https://calliope.cc/start/tipps", comment:"URL in Help screen"))
        }
        if segue.identifier == "moreEditors" {
            webViewController.url = URL(string: NSLocalizedString("https://calliope.cc/programmieren/editoren", comment:"URL in Help screen"))
        }
        if segue.identifier == "moreCalliope" {
            webViewController.url = URL(string: NSLocalizedString("https://calliope.cc", comment:"URL in Help screen"))
        }
        if segue.identifier == "morePlayground" {
            webViewController.url = URL(string: NSLocalizedString("https://calliope.cc/programmieren/playground", comment:"URL in Help screen"))
        }
        if segue.identifier == "moreCalliopeMini" {
            webViewController.url = URL(string: NSLocalizedString("https://calliope.cc/calliope-mini/uebersicht", comment:"URL in Help screen"))
        }
        if segue.identifier == "installstartprogram" {
            webViewController.url = URL(string: NSLocalizedString("https://calliope.cc/programmieren/mobil/hilfe", comment:"URL in Help screen"))
        }
    }

}
