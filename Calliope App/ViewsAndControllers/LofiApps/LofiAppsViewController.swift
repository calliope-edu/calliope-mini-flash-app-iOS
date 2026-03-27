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
    
    private let infoItem = AppItem(tileItem: TileItem(title: "INFO", imageName: "info", color: Color("calliope-pink"), textColor: .white), url: "https://calliope.cc/programmieren/mobil/ble-anwendungen")
    private let appItems = [
        AppItem(tileItem: TileItem(title: "ROBOTER MIT GESICHTSERKENNUNG STEUERN",    imageName: "facerobot", color: Color("calliope-lilablau"), textColor: .white), url: "https://go.calliope.cc/facerobot?mobile=true"),
        AppItem(tileItem: TileItem(title: "SPRACHROBOTER",  imageName: "speak", color: Color("calliope-orange"), textColor: .white), url: "https://cardboard.lofirobot.com/apps/talking-robots"),
        AppItem(tileItem: TileItem(title: "STEUERUNG PER COMPUTER",    imageName: "control", color: Color("calliope-turqoise"), textColor: .white), url: "https://go.calliope.cc/apps/control/index.html?mobile=true"),
        AppItem(tileItem: TileItem(title: "OBJEKTERKENNUNG MIT KÜNSTLICHER INTELLIGENZ",   imageName: "teachablemachine", color: Color("calliope-darkgreen"), textColor: .white), url: "https://go.calliope.cc/teachablemachine/index.html?mobile=true"),
    ]

    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        let tileData = TileData(rightItems: appItems)
        let appsPage = TilePageLayout(leftItem: infoItem, data: tileData, leftItemOnTap: onInfoSelected, rightItemsOnTap: onAppSelected)
        return UIHostingController(coder: coder, rootView: appsPage)
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
                lofiAppDetailViewController.appTitle = selectedApp!.tileItem.title
                lofiAppDetailViewController.url = URL(string: selectedApp!.url)
            }
        else if segue.identifier == "showInfo" {
            let infoViewController = segue.destination as! InfoViewController
            infoViewController.url = URL(string: infoItem.url)
        }
    }
    
    func onAppSelected(app: AppItem) {
        selectedApp = app
        performSegue(withIdentifier: "showLofiWebView", sender: self)
    }
    
    func onInfoSelected(info: AppItem) {
        performSegue(withIdentifier: "showInfo", sender: self)
    }
}

struct AppItem: HasTileItem {
    let tileItem: TileItem
    let url: String
}
