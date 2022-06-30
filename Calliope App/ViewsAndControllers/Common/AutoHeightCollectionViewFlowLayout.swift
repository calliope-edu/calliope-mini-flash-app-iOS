//
//  ProgramsCollectionViewFlowLayout.swift
//  Calliope App
//
//  Created by Tassilo Karge on 12.06.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

class AutoHeightCollectionViewFlowLayout: UICollectionViewFlowLayout {

    var maxCellWidth: CGFloat { 500 }
    var defaultCellHeight: CGFloat { 100 }
    var cellSpacing: CGFloat { 10 }

    // Compute the width of a full width cell
    // for a given bounds
    func cellWidth(bounds: CGRect) -> CGFloat {
        guard let collectionView = collectionView else {
            return 0
        }

        let insets = collectionView.contentInset
        let width = bounds.width - insets.left - insets.right

        if width < 0 { return 0 }

        let usableWidth = width - cellSpacing
        let maxNumCells = ceil(usableWidth / maxCellWidth)
        let cellWidth = usableWidth / maxNumCells - cellSpacing

        return cellWidth
    }

    // Update the estimatedItemSize for a given bounds
    func updateEstimatedItemSize(bounds: CGRect) {
        estimatedItemSize = CGSize(
            width: cellWidth(bounds: bounds),
            // Make the height a reasonable estimate to
            // ensure the scroll bar remains smooth
            height: defaultCellHeight
        )
    }

    // assign an initial estimatedItemSize by calling
    // updateEstimatedItemSize. prepare() will be called
    // the first time a collectionView is assigned
    override func prepare() {
        super.prepare()

        let bounds = collectionView?.bounds ?? .zero
        updateEstimatedItemSize(bounds: bounds)
    }

    // If the current collectionView bounds.size does
    // not match newBounds.size, update the
    // estimatedItemSize via updateEstimatedItemSize
    // and invalidate the layout
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else {
            return false
        }

        let oldSize = collectionView.bounds.size
        guard oldSize != newBounds.size else { return false }

        updateEstimatedItemSize(bounds: newBounds)
        return true
    }
}
