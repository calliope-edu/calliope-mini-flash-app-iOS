//
//  MasonryLayout.swift
//  Calliope App
//
//  Created by Calliope on 26.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct MasonryLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    init(columns: Int, spacing: CGFloat = 16) {
        self.columns = columns
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {

        let width = proposal.width ?? 0
        let columnWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)

        var columnHeights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let shortestColumn = columnHeights.enumerated()
                .min(by: { $0.element < $1.element })!
                .offset

            let size = subview.sizeThatFits(
                ProposedViewSize(width: columnWidth, height: nil)
            )

            columnHeights[shortestColumn] += size.height + spacing
        }

        return CGSize(
            width: width,
            height: (columnHeights.max() ?? 0) - spacing
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {

        let columnWidth = (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)

        var columnHeights = Array(repeating: bounds.minY, count: columns)

        for subview in subviews {
            let shortestColumn = columnHeights.enumerated()
                .min(by: { $0.element < $1.element })!
                .offset

            let size = subview.sizeThatFits(
                ProposedViewSize(width: columnWidth, height: nil)
            )

            let x = bounds.minX + CGFloat(shortestColumn) * (columnWidth + spacing)
            let y = columnHeights[shortestColumn]

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: columnWidth, height: size.height)
            )

            columnHeights[shortestColumn] += size.height + spacing
        }
    }
}
