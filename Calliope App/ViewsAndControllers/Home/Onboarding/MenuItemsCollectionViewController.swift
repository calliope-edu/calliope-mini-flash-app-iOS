//
//  MenuItemsCollectionViewController.swift.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.12.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class MenuItemsCollectionViewController: UIViewController, AnimatingTutorialViewController {
    
    public var finishedCallback: () -> () = { }
    
    @IBOutlet var collectionView: UICollectionView?
    
    var cellSize: CGSize = CGSize(width: 250, height: 65)
    
    var cellIdentifier: String = "cell"
    
    var cellConfigurations: [(String?, UIImage?, [UIImage]?, [UIImage]?)] =
        [(NSLocalizedString("Oracle", comment: ""), #imageLiteral(resourceName: "num_01.pdf"), nil, nil),
         (NSLocalizedString("Paper, Rock, Scissor", comment: ""), #imageLiteral(resourceName: "num_02.pdf"), nil, nil),
         (NSLocalizedString("Multiplication tables", comment: ""), #imageLiteral(resourceName: "num_03.pdf"), nil, nil),
         (NSLocalizedString("Noise-o-meter", comment: ""), #imageLiteral(resourceName: "num_04.pdf"), nil, nil),
         (NSLocalizedString("Bluetooth", comment: ""), #imageLiteral(resourceName: "num_05.pdf"), nil, nil)]
    
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
