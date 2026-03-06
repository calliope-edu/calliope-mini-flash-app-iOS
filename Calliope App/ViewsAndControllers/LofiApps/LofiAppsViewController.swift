//
//  LofiAppsViewController.swift
//  Calliope App
//
//  Created by OpenAI Assistant on 2026-02-20.
//

import UIKit
import SwiftUI

/// A blank view controller displayed under the new "LofiApps" tab.
final class LofiAppsViewController: UIViewController {
    
    private var selectedApp: AppItem?
    private var infoUrl: String?

    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: LofiAppsPage(parentViewController: self))
    }
    
    override func viewWillAppear(_ animated: Bool)  {
        MatrixConnectionViewController.instance?.connectionDescriptionText = NSLocalizedString("Calliope mini verbinden!", comment: "")
        MatrixConnectionViewController.instance?.calliopeClass = DiscoveredBLEDevice.self
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "showLofiWebView" {
                guard selectedApp != nil else {
                    LogNotify.log("Selected App is not set. This should not happen.", level: LogNotify.LEVEL.ERROR)
                    return
                }
                let lofiAppDetailViewController = segue.destination as! LofiAppDetailViewController
                lofiAppDetailViewController.appTitle = selectedApp!.title
                lofiAppDetailViewController.url = URL(string: selectedApp!.url)
            }
        else if segue.identifier == "showInfo" {
            guard infoUrl != nil else {
                LogNotify.log("InfoUrl is not set. This should not happen.", level: LogNotify.LEVEL.ERROR)
                return
            }
            let infoViewController = segue.destination as! InfoViewController
            infoViewController.url = URL(string: infoUrl!)
        }
        }
    
    func setSelectedApp(app: AppItem) {
        selectedApp = app
    }
    
    func selectedInfo(url: String) {
        self.infoUrl = url
    }
}
