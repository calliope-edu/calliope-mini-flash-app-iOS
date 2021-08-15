//
//  PlaygroundInstructionsCollectionCollectionViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.08.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class PlaygroundInstructionsCollectionCollectionViewController: NewsCollectionViewController {

    override var news: [NewsItemProtocol] {
        get { [
            NewsItemWithStaticImage(image: #imageLiteral(resourceName: "playground_startscreen/calliope_playgrounds_appshop"), text: "Download the Swift Playgrounds App".localized, url: URL(string: "https://itunes.apple.com/gb/app/swift-playgrounds/id908519492")!, color: "#FFFFFF", textcolor: "#000000"),
            NewsItemWithStaticImage(image: #imageLiteral(resourceName: "playground_startscreen/calliope_playgrounds_5"), text: "Upload the start program to your Calliope".localized, url: URL(string: "about:blank")!, color: "#7467DE", textcolor: "#ffffff"),
            NewsItemWithStaticImage(image:  #imageLiteral(resourceName: "playground_startscreen/calliope_playgrounds_B"), text: "Subscribe to the Calliope Playgrounds".localized, url: URL(string: "https://developer.apple.com/ul/sp0?url=https://calliope-edu.github.io/playground/feed.json")!, color: "#7467DE", textcolor: "#ffffff")
        ] }
        set {
            fatalError("these are not really news, but static content")
        }
    }

    override func loadNews() {
        //deliberately does nothing, "news items" are statically defined
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == 1 {
            let program = DefaultProgram.defaultProgram
            FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
            return
        }
        UIApplication.shared.open(news[indexPath.item].url)
    }
}
