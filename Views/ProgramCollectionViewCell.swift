//
//  ProgramCollectionViewCell.swift
//  Calliope
//
//  Created by Tassilo Karge on 08.06.19.
//

import UIKit

protocol ProgramShareDelegate {
	func share(cell: ProgramCollectionViewCell)
}

class ProgramCollectionViewCell: UICollectionViewCell {
	@IBOutlet weak var image: UIImageView!
	@IBOutlet weak var text: UITextView!
	@IBOutlet weak var name: UILabel!
	@IBOutlet weak var nameEditField: UITextField!
	@IBOutlet weak var editButton: UIButton!
	@IBOutlet weak var shareButton: UIButton!

	public var program: HexFile! {
		didSet {
			name.text = program.name
			nameEditField.text = program.name
		}
	}

	public var delegate: ProgramShareDelegate!

	public var editing = false {
		didSet {
			if (!editing) {
				name.text = nameEditField.text
				program.name = nameEditField.text ?? "---"
				editButton.setTitle("Edit", for: .normal)
			} else {
				nameEditField.text = name.text
				editButton.setTitle("Finished", for: .normal)
			}
			name.isHidden = editing
			nameEditField.isHidden = !editing
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		text.textContainer.exclusionPaths = [
			UIBezierPath(rect: self.convert(image.frame.intersection(text.frame), to: text)),
			UIBezierPath(rect: self.convert(shareButton.frame.intersection(text.frame), to: text))]
	}



	@IBAction func editButtonClicked(_ sender: Any) {
		editing = !editing
	}

	@IBAction func shareButtonClicked(_ sender: Any) {
		self.delegate.share(cell: self)
	}

}
