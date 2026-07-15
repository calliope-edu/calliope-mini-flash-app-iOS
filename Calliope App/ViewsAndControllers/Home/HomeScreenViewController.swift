//
//  HomeScreenViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 13.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit
import Network
import SwiftUI

class HomeScreenViewController: UIViewController {
    var network: Network = Network()
    private var selectedTile: NewsItem?

    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: HomeScreenView(onTileSelected: onTileSelected, viewModel: HomeScreenViewModel()))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // MatrixConnectionViewController.instance?.calliopeClass = nil // TODO: Removes Connector on HomePage -> Is this desired behaviour?
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetails" {
            guard selectedTile != nil else {
                LogNotify.log("Selected Tile is not set. This should not happen.", level: LogNotify.LEVEL.ERROR)
                return
            }
            let newsDetailWebViewController = segue.destination as! NewsDetailWebViewController
            guard let url = URL(string: selectedTile!.url) else {
                LogNotify.log("String \(selectedTile!.url) is not a valid URL.", level: LogNotify.LEVEL.ERROR)
                return
            }
            newsDetailWebViewController.url = url
        }
    }
    
    func onTileSelected(tile: NewsItem) {
        if network.isNetworkAvailable() {
            selectedTile = tile
            performSegue(withIdentifier: "showDetails", sender: self)

        } else {
            performSegue(withIdentifier: "showOnboardingOffline", sender: self)
        }
    }
}

