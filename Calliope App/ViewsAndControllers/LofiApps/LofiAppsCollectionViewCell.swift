//
//  LofiAppsCollectionViewCell.swift
//  Calliope App
//
//  Created by Calliope on 20.02.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import UIKit

class LofiAppsCollectionViewCell: UICollectionViewCell {
    // MARK: - Reuse Identifier
    static let reuseIdentifier = "LofiAppCell"

    // MARK: - UI Outlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    // MARK: - Configuration
    func configure(_ title: String) {
        imageView.image = UIImage(named: "calliope_datalogger_extension")
        titleLabel.text = title
    }

    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        // Styling that runs once per cell instance
        /*imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        layer.cornerRadius = 8
        layer.masksToBounds = true*/
    }
}
