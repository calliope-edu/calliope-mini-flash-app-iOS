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
        [("Flip through the programs by pressing the keys A or B", nil, [#imageLiteral(resourceName: "menu_01.pdf")], nil),
         ("By shaking, you confirm the selection", nil, [#imageLiteral(resourceName: "menu_02.pdf")], nil),
         ("Press both A and B to return to the menu", nil, [#imageLiteral(resourceName: "menu_03.pdf")], nil)]
    
    var animationStep: Int = 0
    
    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return proxyCollectionView(collectionView, numberOfItemsInSection: section)
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return proxyCollectionView(collectionView, cellForItemAt: indexPath)
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return proxyCollectionView(collectionView, layout: collectionViewLayout, sizeForItemAt: indexPath)
    }
    
}
