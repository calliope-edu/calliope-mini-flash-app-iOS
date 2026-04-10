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

    @IBOutlet weak var homeStackView: UIStackView!
    
    var network: Network = Network()
    
    private let gettingStartedItem = NewsItem2(tileItem: TileItem(title: "GETTING STARTED", imageSource: ImageSource.local("teaser_onboarding"), color: Color("calliope-pink"), textColor: .white), url: "https://calliope.cc/programmieren/mobil/ipad")
    private var newsItems: [NewsItem2] = []
    private var loadedOnlineContent = false
    private var appsPage: TilePageLayout<NewsItem2>? = nil
    private var tileData: TileData<NewsItem2> = TileData(rightItems: [])
    private var selectedTile: NewsItem2?
    
    func loadNews() {
        NewsManager.getNews { [weak self] result in
            switch result {
            case .success(let news):
                self?.newsItems = news.map{newsItem in NewsItem2(tileItem: TileItem(title: newsItem.text, imageSource: newsItem.getImage(), color: Color(hex: newsItem.color!) ?? Color("calliope-pink"), textColor: Color(hex: newsItem.textcolor!) ?? Color(.black)), url: newsItem.url.absoluteString)}
                self?.loadedOnlineContent = true
            case .failure(_):
                self?.newsItems = NewsManager.getDefaultNews().map{newsItem in NewsItem2(tileItem: TileItem(title: newsItem.text, imageSource: newsItem.getImage(), color: Color(hex: newsItem.color!) ?? Color("calliope-pink"), textColor: Color(hex: newsItem.textcolor!) ?? Color(.black)), url: newsItem.url.absoluteString)}
                self?.loadedOnlineContent = false
            }
            DispatchQueue.main.async {
                self!.tileData.rightItems = self!.newsItems
            }
        }
    }
    
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        if !loadedOnlineContent {
            loadNews()
        }
        appsPage = TilePageLayout(leftItem: gettingStartedItem, data:tileData, leftItemOnTap: onIntroSelected, rightItemsOnTap: onTileSelected)
        return UIHostingController(coder: coder, rootView: appsPage)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // MatrixConnectionViewController.instance?.calliopeClass = nil // TODO: Removes Connector on HomePage -> Is this desired behaviour?
    }
    
    func onIntroSelected(introTile: NewsItem2) {
        if network.isNetworkAvailable() {
            selectedTile = introTile
            performSegue(withIdentifier: "showDetails", sender: self)

        } else {
            performSegue(withIdentifier: "showOnboardingOffline", sender: self)
        }
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
    
    func onTileSelected(tile: NewsItem2) {
        selectedTile = tile
        performSegue(withIdentifier: "showDetails", sender: self)
    }
}

struct NewsItem2: HasTileItem {
    let tileItem: TileItem
    let url: String
    
}
