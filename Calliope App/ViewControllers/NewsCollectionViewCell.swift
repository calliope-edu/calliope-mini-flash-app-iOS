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
			newsTitle.text = news?.text
			news?.loadImage({ [weak self] result in
				switch result {
				case .success(let image):
					DispatchQueue.main.async {
						self?.newsImageView.image = image
					}
				case .failure(let error):
					//TODO: handle error
					break
				}
			})
		}
	}

	@IBOutlet weak var newsImageView: UIImageView!
	@IBOutlet weak var newsTitle: UILabel!
}
