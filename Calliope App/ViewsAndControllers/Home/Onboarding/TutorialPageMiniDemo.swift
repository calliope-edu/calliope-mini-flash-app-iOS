//
//  TutorialPageMiniDemo.swift
//  Calliope App
//
//  Created by Tassilo Karge on 16.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageMiniDemo: TutorialPageViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    let cellIdentifier = "cell"
    let secondaryImageDefaultHeight: CGFloat = 40
    
    let animationSpeed = 5.0
    
    let cellConfigurations = [("Greetings", #imageLiteral(resourceName: "num_01.pdf"), [#imageLiteral(resourceName: "demoa_01.pdf")], nil),
                              ("Button A", #imageLiteral(resourceName: "num_02.pdf"), [#imageLiteral(resourceName: "demoa_02.pdf")], nil),
                              ("Button B", #imageLiteral(resourceName: "num_03.pdf"), [#imageLiteral(resourceName: "demoa_03.pdf")], nil),
                              ("Button A and B", #imageLiteral(resourceName: "num_04.pdf"), [#imageLiteral(resourceName: "demoa_04.pdf")], nil),
                              ("Shake", #imageLiteral(resourceName: "num_05.pdf"), [#imageLiteral(resourceName: "demoa_05.pdf")], nil),
                              ("Ready!", #imageLiteral(resourceName: "num_06.pdf"),
                               [#imageLiteral(resourceName: "ani_done_00.pdf"), #imageLiteral(resourceName: "ani_done_01.pdf"), #imageLiteral(resourceName: "ani_done_02.pdf"), #imageLiteral(resourceName: "ani_done_03.pdf"),
                                #imageLiteral(resourceName: "ani_done_04.pdf"), #imageLiteral(resourceName: "ani_done_06.pdf"), #imageLiteral(resourceName: "ani_done_07.pdf"),
                                #imageLiteral(resourceName: "ani_done_08.pdf"), #imageLiteral(resourceName: "ani_done_09.pdf"), #imageLiteral(resourceName: "ani_done_10.pdf"), #imageLiteral(resourceName: "ani_done_11.pdf"),
                                #imageLiteral(resourceName: "ani_done_12.pdf"), #imageLiteral(resourceName: "ani_done_13.pdf"), #imageLiteral(resourceName: "ani_done_14.pdf"), #imageLiteral(resourceName: "ani_done_15.pdf"),
                                #imageLiteral(resourceName: "ani_done_16.pdf"), #imageLiteral(resourceName: "ani_done_17.pdf"), #imageLiteral(resourceName: "ani_done_18.pdf"), #imageLiteral(resourceName: "ani_done_18.pdf"), #imageLiteral(resourceName: "ani_done_18.pdf"), #imageLiteral(resourceName: "ani_done_18.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"),
                                #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"),
                                #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf"), #imageLiteral(resourceName: "ani_done_19.pdf")],
                               [#imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
                                #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
                                #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
                                #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"),
                                #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_00.pdf"), #imageLiteral(resourceName: "rgb_18.pdf"), #imageLiteral(resourceName: "rgb_18.pdf"),
                                #imageLiteral(resourceName: "rgb_20.pdf"), #imageLiteral(resourceName: "rgb_20.pdf"), #imageLiteral(resourceName: "rgb_22.pdf"), #imageLiteral(resourceName: "rgb_22.pdf"),
                                #imageLiteral(resourceName: "rgb_24.pdf"), #imageLiteral(resourceName: "rgb_24.pdf"), #imageLiteral(resourceName: "rgb_26.pdf"), #imageLiteral(resourceName: "rgb_26.pdf")])]
    
    var animationStep = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animate()
    }
    
    func animate() {
        if animationStep < cellConfigurations.count {
            let indexPath = IndexPath(row: animationStep, section: 0)
            animationStep += 1
            collectionView.insertItems(at: [indexPath])
            self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
            delay(time: 3.0, self.animate)
        } else {
            animationStep += 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(animationStep, cellConfigurations.count)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell =  collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? OnboardingMiniDemoCollectionViewCell else {
            fatalError("only miniDemo cells must be provided to miniDemo page!")
        }
        let cellData = cellConfigurations[indexPath.row]
        
        setCellData(cell, cellData)
        
        if (animationStep == indexPath.row + 1) {
            cell.contentView.alpha = 0
            delay(time: 0.3) {
                self.cellFadeInAnimation(cell)
            }
        } else {
            startCellImageAnimations(cell)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 300, height: 270)
    }
    
    private func setCellData(_ cell: OnboardingMiniDemoCollectionViewCell, _ cellData: (String, UIImage, [UIImage], [UIImage]?)) {
        
        cell.title.text = cellData.0
        cell.number.image = cellData.1
        
        if cellData.2.count > 1 {
            cell.mainImage.animationImages = cellData.2
            cell.mainImage.image = cellData.2[0]
            cell.mainImage.animationDuration = animationSpeed
        } else if cellData.2.count > 0 {
            cell.mainImage.animationImages = nil
            cell.mainImage.image = cellData.2[0]
        } else {
            fatalError("There must be a main image for every miniDemo cell")
        }
        
        if cellData.3 == nil || cellData.3!.count == 0 {
            cell.secondaryImageHeight.constant = 0
        } else if cellData.3!.count > 1 {
            cell.secondaryImageHeight.constant = secondaryImageDefaultHeight
            //set animation images
            cell.secondaryImage.animationImages = cellData.3
            cell.secondaryImage.image = cellData.3![0]
            cell.secondaryImage.animationDuration = animationSpeed
        } else {
            cell.secondaryImageHeight.constant = secondaryImageDefaultHeight
            //set static image
            cell.secondaryImage.animationImages = nil
            cell.secondaryImage.image = cellData.3![0]
        }
    }
    
    private func cellFadeInAnimation(_ cell: OnboardingMiniDemoCollectionViewCell) {
        UIView.animate(withDuration: 0.5, animations: {
            cell.contentView.alpha = 1.0
        }) { (_) in
            self.startCellImageAnimations(cell)
        }
    }
    
    private func startCellImageAnimations(_ cell: OnboardingMiniDemoCollectionViewCell) {
        if cell.mainImage.animationImages != nil {
            cell.mainImage.startAnimating()
        }
        if cell.secondaryImage.animationImages != nil {
            cell.secondaryImage.startAnimating()
        }
    }
}
