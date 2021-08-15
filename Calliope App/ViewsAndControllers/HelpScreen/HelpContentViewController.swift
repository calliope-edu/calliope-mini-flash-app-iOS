//
//  HelpContentViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.08.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

class HelpContentViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
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
        if segue.identifier == "editoren" {
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
