//
//  MenuNavigationCollectionViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.12.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class MenuNavigationCollectionViewController: UIViewController, AnimatingTutorialViewController {

    public var finishedCallback: () -> () = { }
    
    @IBOutlet var collectionView: UICollectionView?
    
    var cellSize: CGSize = CGSize(width: 220, height: 220)
    
    var cellIdentifier: String = "cell"
    
    var cellConfigurations: [(String?, UIImage?, [UIImage]?, [UIImage]?)] =
        [("Flip through the programs by pressing the keys A or B".localized, nil, [#imageLiteral(resourceName: "menu_01.pdf")], nil),
         ("By shaking, you confirm the selection".localized, nil, [#imageLiteral(resourceName: "menu_02.pdf")], nil),
         ("Press both A and B to return to the menu".localized, nil, [#imageLiteral(resourceName: "menu_03.pdf")], nil),
         //SECTION 2
         ("Oracle".localized, #imageLiteral(resourceName: "num_01.pdf"), nil, nil),
         ("Paper, Rock, Scissor".localized, #imageLiteral(resourceName: "num_02.pdf"), nil, nil),
         ("Multiplication tables".localized, #imageLiteral(resourceName: "num_03.pdf"), nil, nil),
         ("Noise-o-meter".localized, #imageLiteral(resourceName: "num_04.pdf"), nil, nil),
         ("Bluetooth".localized, #imageLiteral(resourceName: "num_05.pdf"), nil, nil)]
    
    var animationStep: Int = 0

    let firstSectionCount = 3

    func indexPathForItem(_ number: Int) -> IndexPath {
        return number < firstSectionCount ? IndexPath(item: number, section: 0)
            : IndexPath(item: number - firstSectionCount, section: 1)
    }
    
    func itemForIndexPath(_ indexPath: IndexPath) -> Int {
        return indexPath.section == 0 ? indexPath.item : indexPath.item + firstSectionCount
    }
    
    @objc func numberOfSections(in collectionView: UICollectionView) -> Int {
        2
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? min(animationStep, firstSectionCount)
            : max(0, min(animationStep - firstSectionCount, cellConfigurations.count - firstSectionCount))
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if (indexPath.section == 0) {
            cellIdentifier = "cell"
        } else {
            cellIdentifier = "cell2"
        }

        let cell = proxyCollectionView(collectionView, cellForItemAt: indexPath)
        if indexPath.section == 1 && indexPath.item == 4 {
            (cell as! OnboardingCollectionViewCell).title?.textColor = #colorLiteral(red: 0.2590000033, green: 0.7879999876, blue: 0.7879999876, alpha: 1)
        } else {
            (cell as! OnboardingCollectionViewCell).title?.textColor = UIColor.black
        }
        return cell
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 ? cellSize : CGSize(width: 250, height: 65)
    }
}
