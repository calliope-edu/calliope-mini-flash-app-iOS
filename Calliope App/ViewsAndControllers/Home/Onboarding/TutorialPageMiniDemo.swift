//
//  TutorialPageMiniDemo.swift
//  Calliope App
//
//  Created by Tassilo Karge on 16.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageMiniDemo: TutorialPageViewController, AnimatingTutorialViewController {
    
    @IBOutlet weak var collectionView: UICollectionView?
    
    var cellSize: CGSize = CGSize(width: 280, height: 250)
    
    var cellIdentifier = "cell"
    var secondaryImageDefaultHeight: CGFloat = 40
    
    var animationSpeed = 0.15
    
    var cellConfigurations: [(String?, UIImage?, [UIImage]?, [UIImage]?)] =
        [(NSLocalizedString("Greetings", comment: ""), #imageLiteral(resourceName: "num_01.pdf"), [#imageLiteral(resourceName: "demoa_01.pdf")], nil),
         (NSLocalizedString("Button A", comment: ""), #imageLiteral(resourceName: "num_02.pdf"), [#imageLiteral(resourceName: "demoa_02.pdf")], nil),
         (NSLocalizedString("Button B", comment: ""), #imageLiteral(resourceName: "num_03.pdf"), [#imageLiteral(resourceName: "demoa_03.pdf")], nil),
         (NSLocalizedString("Button A and B", comment: ""), #imageLiteral(resourceName: "num_04.pdf"), [#imageLiteral(resourceName: "demoa_04.pdf")], nil),
         (NSLocalizedString("Shake", comment: ""), #imageLiteral(resourceName: "num_05.pdf"), [#imageLiteral(resourceName: "demoa_05.pdf")], nil),
         (NSLocalizedString("Ready!", comment: ""), #imageLiteral(resourceName: "num_06.pdf"),
          [#imageLiteral(resourceName: "ani_done_00.pdf"), #imageLiteral(resourceName: "ani_done_01.pdf"), #imageLiteral(resourceName: "ani_done_02.pdf"), #imageLiteral(resourceName: "ani_done_03.pdf"),
           #imageLiteral(resourceName: "ani_done_04.pdf"), #imageLiteral(resourceName: "ani_done_06.pdf"), #imageLiteral(resourceName: "ani_done_07.pdf"), #imageLiteral(resourceName: "ani_done_08.pdf"),
           #imageLiteral(resourceName: "ani_done_09.pdf"), #imageLiteral(resourceName: "ani_done_10.pdf"), #imageLiteral(resourceName: "ani_done_11.pdf"), #imageLiteral(resourceName: "ani_done_12.pdf"),
           #imageLiteral(resourceName: "ani_done_13.pdf"), #imageLiteral(resourceName: "ani_done_14.pdf"), #imageLiteral(resourceName: "ani_done_15.pdf"), #imageLiteral(resourceName: "ani_done_16.pdf"),
           #imageLiteral(resourceName: "ani_done_17.pdf"), #imageLiteral(resourceName: "ani_done_18.pdf"), #imageLiteral(resourceName: "ani_done_18.pdf"), #imageLiteral(resourceName: "ani_done_18.pdf"),
           #imageLiteral(resourceName: "ani_done_18.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"),
           #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"),
           #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf")],
          [#imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
           #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
           #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
           #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
           #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
           #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_18.pdf"), #imageLiteral(resourceName: "rgb_18.pdf"),
           #imageLiteral(resourceName: "rgb_20.pdf"), #imageLiteral(resourceName: "rgb_20.pdf"), #imageLiteral(resourceName: "rgb_22.pdf"), #imageLiteral(resourceName: "rgb_22.pdf"),
           #imageLiteral(resourceName: "rgb_24.pdf"), #imageLiteral(resourceName: "rgb_24.pdf"), #imageLiteral(resourceName: "rgb_26.pdf"), #imageLiteral(resourceName: "rgb_26.pdf")])]
    
    var animationStep = 0
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animate()
    }
    
    //MARK: proxy functions to settle UICollectionViewDataSource Objective C Interop problem
    
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
