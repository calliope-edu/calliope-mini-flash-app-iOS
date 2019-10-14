//
//  EditorCollectionViewCell.swift
//  Calliope
//
//  Created by Tassilo Karge on 08.06.19.
//

import UIKit

class EditorCollectionViewCell: UICollectionViewCell {
	
    @IBOutlet weak var logo: UIImageView!
    @IBOutlet weak var name: UILabel!
    
    var editor: SettingsKey!

	override func awakeFromNib() {
		super.awakeFromNib()
	}
}
