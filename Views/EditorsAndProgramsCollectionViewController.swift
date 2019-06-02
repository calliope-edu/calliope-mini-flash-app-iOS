//
//  EditorsAndProgramsCollectionViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 02.06.19.
//

import UIKit

private let reuseIdentifierWebEditor = "webEditorCell"
private let reuseIdentifierOfflineEditor = "localEditorCell"
private let reuseIdentifierPlayground = "playgroundCell"
private let reuseIdentifierProgram = "editableProgramCell"

private let reuseIdentifierHeader = "headerWithButton"

class EditorsAndProgramsCollectionViewController: UICollectionViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifierWebEditor)
		self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifierOfflineEditor)
		self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifierPlayground)
		self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifierProgram)

		self.collectionView!.register(UICollectionReusableView.self, forSupplementaryViewOfKind: "header", withReuseIdentifier: reuseIdentifierHeader)

        // Do any additional setup after loading the view.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
		if section == 0 {
			return 4
		} else {
			return 0
		}
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell: UICollectionViewCell
		if indexPath.first == 0 {
			cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierWebEditor, for: indexPath)
		} else {
			cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath)
		}
        // Configure the cell
    
        return cell
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}
