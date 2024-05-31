//
//  ChartCollectionViewController.swift
//  Calliope App
//
//  Created by itestra on 27.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit


class ChartCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UIDocumentPickerDelegate {

    private let reuseIdentifierProgram = "sensorRecording"
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: UICollectionViewCell
        cell = createProjectCell(collectionView, indexPath)
        return cell
    }
    
    private func createProjectCell(_ collectionView: UICollectionView, _ indexPath: IndexPath) -> UICollectionViewCell {
        let cell: ChartViewController
        
        //TODO: Configure the cell
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath) as! ChartViewController
        cell.setChart(values: [2.0, 3.0, 4.0, 3.0, 3.0, 3.0, 4.0])
        cell.backgroundColor = .calliopeTurqoise
        
        return cell
    }
    func collectionView(_ collectionView: UICollectionView,
                            layout collectionViewLayout: UICollectionViewLayout,
                            sizeForItemAt indexPath: IndexPath) -> CGSize {
            let kWhateverHeightYouWant = 300
            return CGSizeMake(collectionView.bounds.size.width, CGFloat(kWhateverHeightYouWant))
    }
}
