//
//  CalliopeBlocksCollectionViewController.swift
//  Calliope App
//
//  Created by itestra GmbH on 04.04.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class CalliopeBlocksCollectionViewController: NewsCollectionViewController {

    override var news: [NewsItemProtocol] {
        get { [
            NewsItemWithStaticImage(image: #imageLiteral(resourceName: "blr_03"), text: NSLocalizedString("Verbinde deinen Calliope mini mit dem Ipad", comment: ""), url: URL(string: "https://itunes.apple.com/gb/app/swift-playgrounds/id908519492")!, color: "#03adfc", textcolor: "#FFFFFF"),
            NewsItemWithStaticImage(image: #imageLiteral(resourceName: "playground_startscreen/calliope_playgrounds_appshop"), text: NSLocalizedString("Übertrage das Scratch Startprogramm, um deinen Calliope mini programmierbar zu machen. ", comment: ""), url: URL(string: "https://itunes.apple.com/gb/app/swift-playgrounds/id908519492")!, color: "#03adfc", textcolor: "#FFFFFF"),
            NewsItemWithStaticImage(image: #imageLiteral(resourceName: "playground_startscreen/calliope_playgrounds_appshop"), text: NSLocalizedString("Lade die Calliope mini Blocks App aus dem App Store und lege direkt los!", comment: ""), url: URL(string: "https://itunes.apple.com/gb/app/swift-playgrounds/id908519492")!, color: "#03adfc", textcolor: "#FFFFFF"),
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
            let program = DefaultProgram(programName: NSLocalizedString("Calliope mini 3", comment:""), url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV3Url.rawValue)!)
            FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
            return
        }
        UIApplication.shared.open(news[indexPath.item].url)
    }
}

