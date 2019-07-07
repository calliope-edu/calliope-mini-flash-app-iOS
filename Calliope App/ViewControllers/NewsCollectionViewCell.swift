//
//  NewsCollectionViewCell.swift
//  Calliope App
//
//  Created by Tassilo Karge on 29.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class NewsCollectionViewCell: UICollectionViewCell {
	var news: NewsItem? {
		didSet {
			loadNews()
		}
	}

	@IBOutlet weak var newsImageView: UIImageView!
	@IBOutlet weak var newsTitle: UILabel!

	private func loadNews() {
		DispatchQueue.main.async {
			UIView.animate(withDuration: 0.2) {
				self.newsTitle.text = self.news?.text
				self.backgroundColor = self.news?.color != nil ? UIColor(hex: self.news!.color) : UIColor.white
			}
		}
		news?.loadImage({ [weak self] result in
			switch result {
			case .success(let image):
				DispatchQueue.main.async { UIView.animate(withDuration: 0.2) {
					self?.newsImageView.image = image
					}
				}
			case .failure(let error):
				//TODO: handle error
				break
			}
		})
	}
}
