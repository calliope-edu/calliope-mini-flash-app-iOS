//
//  EditorCollectionViewCell.swift
//  Calliope
//
//  Created by Tassilo Karge on 08.06.19.
//

import UIKit

class EditorCollectionViewCell: UICollectionViewCell {
	@IBOutlet weak var button: UIButton!

	lazy var widthConstraint: NSLayoutConstraint = {
		let c = NSLayoutConstraint(item: self.contentView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 180)
		self.addConstraint(c)
		return c
	}()

	lazy var heightConstraint: NSLayoutConstraint = {
		let c = NSLayoutConstraint(item: self.contentView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 180)
		self.addConstraint(c)
		return c
	}()

	override func awakeFromNib() {
		super.awakeFromNib()

		contentView.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			contentView.leftAnchor.constraint(equalTo: leftAnchor),
			contentView.rightAnchor.constraint(equalTo: rightAnchor),
			contentView.topAnchor.constraint(equalTo: topAnchor),
			contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
			])
	}
}
