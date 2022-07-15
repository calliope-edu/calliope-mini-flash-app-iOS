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

    let widthRatio: CGFloat = 1.2
    
	var news: [NewsItemProtocol] = [] {
		didSet {
			DispatchQueue.main.async {
				self.collectionView.reloadData()
			}
		}
	}

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
        loadNews()
    }

    func loadNews() {
        NewsManager.getNews { [weak self] result in
            switch result {
            case .success(let news):
                self?.news = news
            case .failure(_):
                self?.news = NewsManager.getDefaultNews()
                //TODO: show offline status or restart news discovery
                break
            }
        }
    }
    
    var intermediarySize: CGSize? = nil
    
    override func viewWillTransition(to size: CGSize, with coordinator:
        UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        intermediarySize = CGSize(width: min(collectionView.frame.size.width, size.width), height: min(collectionView.frame.size.height, size.height))
        collectionViewLayout.invalidateLayout()
        
        coordinator.animate(alongsideTransition: { context in
            self.collectionViewLayout.invalidateLayout()
        }, completion: { [weak self] _ in
            self?.intermediarySize = nil
            self?.collectionViewLayout.invalidateLayout()
            self?.layoutDirty = self?.view.bounds.size != size
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
    
    fileprivate func calculateItemSize() -> CGSize {
        let size = intermediarySize ?? self.collectionView.frame.size
        
        let frameHeight = size.height
        let frameWidth = size.width
        
        let spacing: CGFloat = (self.collectionViewLayout as! UICollectionViewFlowLayout).minimumInteritemSpacing
        
        if frameHeight * widthRatio < (frameWidth - spacing) {
            let height = frameHeight
            let width = height * widthRatio
            return CGSize(width: width, height: height)
        } else {
            let width = frameWidth - spacing
            let height = width / widthRatio
            return CGSize(width: width, height: height)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return calculateItemSize()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        let size = intermediarySize ?? collectionView.frame.size
        let scrollDir: UICollectionView.ScrollDirection = size.width > size.height * self.widthRatio ? .horizontal : .vertical

        (self.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection = scrollDir

        let spacing = (self.collectionViewLayout as! UICollectionViewFlowLayout).minimumInteritemSpacing

        if scrollDir == .horizontal {
            let widthPerItem = calculateItemSize().width + spacing
             //item + trailing spacing
            let freeSpace = size.width - widthPerItem * CGFloat(news.count)
            + spacing
            let margin = max(freeSpace / 2.0, spacing / 2.0)
            return UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)
        } else {
            //item + bottom spacing
            let heightPerItem = calculateItemSize().height + spacing
            let freeSpace = size.height - heightPerItem * CGFloat(news.count)
            + spacing
            let margin = max(freeSpace / 2.0, spacing / 2.0)
            return UIEdgeInsets(top: margin, left: spacing / 2.0, bottom: margin, right: spacing / 2.0)
        }
    }
}
