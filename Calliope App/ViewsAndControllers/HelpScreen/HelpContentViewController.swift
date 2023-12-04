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
    let url_online_help = URL(string: "https://calliope.cc/programmieren/mobil/hilfe#top")!
    var successfullyOnline = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        var request = URLRequest(url: self.url_online_help)
        request.httpMethod = "HEAD"
        
        // skip the online check if we were already online
        if successfullyOnline {
            self.performSegue(withIdentifier: "onlineHelp", sender: self)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
            guard let _ = data else {
                self.view.localizeTextViews("Help")
                return
            }
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "onlineHelp", sender: self)
                self.successfullyOnline = true
            }
        }
        task.resume()
    }

    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let webViewController = segue.destination as? HelpWebViewController else {
            return
        }
        webViewController.setContentController(controller: self)
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
        if segue.identifier == "onlineHelp" {
            webViewController.url = url_online_help
        }
    }

}
