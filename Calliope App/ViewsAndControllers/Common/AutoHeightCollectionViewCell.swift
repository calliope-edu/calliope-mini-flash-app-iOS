//
//  AutoHeightCollectionViewCell.swift
//  Calliope App
//
//  Created by Tassilo Karge on 12.06.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

class AutoHeightCollectionViewCell: UICollectionViewCell {
    override func systemLayoutSizeFitting(
            _ targetSize: CGSize,
            withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
            verticalFittingPriority: UILayoutPriority) -> CGSize {

            // Replace the height in the target size to
            // allow the cell to flexibly compute its height
            var targetSize = targetSize
            targetSize.height = CGFloat.greatestFiniteMagnitude

            // The .required horizontal fitting priority means
            // the desired cell width (targetSize.width) will be
            // preserved. However, the vertical fitting priority is
            // .fittingSizeLevel meaning the cell will find the
            // height that best fits the content
            let size = super.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )

            return size
        }
}
