//
//  LofiAppsViewController.swift
//  Calliope App
//
//  Created by OpenAI Assistant on 2026-02-20.
//

import UIKit

/// A blank view controller displayed under the new "LofiApps" tab.
final class LofiAppsViewController: UIViewController {
    @IBOutlet private weak var collectionView: UICollectionView!
    private var apps: [String] = ["Test 1", "Test 2", "Test 3", "Test 1", "Test 2", "Test 3"]

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        collectionView.reloadData()
    }

    private func configureCollectionView() {
        // Register the nib if you used a separate xib for the cell
        // collectionView.register(UINib(nibName: "PhotoCell", bundle: nil),
        //                         forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)

        // Set datasource & delegate (if you use the classic API)
        collectionView.dataSource = self
        // collectionView.delegate   = self
    }
}

extension LofiAppsViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1               // you can have more than one section
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return apps.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Dequeue the custom cell
        guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: LofiAppsCollectionViewCell.reuseIdentifier,
                for: indexPath) as? LofiAppsCollectionViewCell else {
            fatalError("Unable to dequeue PhotoCell")
        }

        let app = apps[indexPath.item]
        cell.configure(app)
        return cell
    }
}
