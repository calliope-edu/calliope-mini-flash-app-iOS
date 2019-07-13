//
//  NewsCollectionViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 29.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

private let reuseIdentifierNewsCell = "newsCell"

class NewsCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

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
				self?.news = NewsManager.getDefaultNews()
				//TODO: show offline status or restart news discovery
				break
			}
		}
    }
    
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		coordinator.animate(alongsideTransition: { (_) in
            self.collectionViewLayout.invalidateLayout()
		}, completion: { _ in
            self.layoutDirty = self.view.bounds.size != size
        })
	}
    
    
    //layoutDirty is a little hack, since an offscreen size change is not reflected in the view bounds.
    //even in viewWillAppear, the bounds are not the correct size yet. So we need to invalidate the
    //collection view layout once more after the bounds update,
    //to make it request new item sizes from its delegate (which is self), that can then use correct bounds.
    var layoutDirty = false
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if (layoutDirty) {
            self.collectionViewLayout.invalidateLayout()
            layoutDirty = false
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

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let frameHeight = self.collectionView.frame.size.height;
		let frameWidth = self.collectionView.frame.size.width;
        
        let spacing: CGFloat = 10
        let widthRatio: CGFloat = 1.2

		if (frameHeight < 500) {
            let height = frameHeight
            let width = min(height * widthRatio, frameWidth - spacing)
			return CGSize(width: width, height: height)
		} else if (frameWidth < 600) {
            let width = frameWidth - spacing
            let height = min(width / widthRatio, frameHeight)
			return CGSize(width: width, height: height)
		} else {
			let height = max(frameHeight / 2 - spacing, 250)
			let width = min(height * widthRatio, frameWidth)
			return CGSize(width: width, height: height)
		}
	}
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
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
