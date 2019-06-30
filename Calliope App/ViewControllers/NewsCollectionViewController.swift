//
//  NewsCollectionViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 29.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

private let reuseIdentifierNewsCell = "newsCell"

class NewsCollectionViewController: UICollectionViewController {

	var news: [NewsItem] = [] {
		didSet {
			DispatchQueue.main.async {
				self.collectionView.reloadData()
			}
		}
	}

    override func viewDidLoad() {
        super.viewDidLoad()

		NewsManager.getNews { [weak self] result in
			switch result {
			case .success(let news):
				self?.news = news
			case .failure(let error):
				//TODO: set default news
				//TODO: show offline status or restart news discovery
				break
			}
		}
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		let selectedUrl = news[self.collectionView.indexPathsForSelectedItems![0].row].url
		let detailWebViewController = segue.destination as! NewsDetailWebViewController
		detailWebViewController.url = selectedUrl
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return news.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierNewsCell, for: indexPath) as! NewsCollectionViewCell

		cell.news = news[indexPath.row]

        return cell
    }

    // MARK: UICollectionViewDelegate

    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return news.count > 1
    }

	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		self.performSegue(withIdentifier: "showNewsUrlSegue", sender: self)
	}

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
