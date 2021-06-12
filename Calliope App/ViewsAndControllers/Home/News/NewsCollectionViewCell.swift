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
            self.newsTitle.text = nil
            self.backgroundColor = UIColor.white
			UIView.animate(withDuration: 0.2) {
				self.newsTitle.text = self.news?.text
                self.newsTitle.textColor = self.news?.textcolor != nil ? UIColor(hex: self.news!.textcolor!) : UIColor.white
				self.backgroundColor = self.news?.color != nil ? UIColor(hex: self.news!.color!) : UIColor.black
			}
		}
        DispatchQueue.main.async {
            self.newsImageView.image = nil
        }
		news?.loadImage({ [weak self] result in
            switch result {
            case .success(let image):
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    UIView.transition(with: self.newsImageView, duration: 0.2, options: .transitionCrossDissolve) {
                        self.newsImageView.image = image
                    }
                }
            case .failure(_):
                //TODO: handle error
                break
            }
        })
	}
}
