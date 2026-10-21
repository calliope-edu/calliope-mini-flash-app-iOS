//
//  FlowLayout.swift
//  Calliope App
//
//  Created by Calliope on 12.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let width = proposal.width else {
            return .zero
        }

        var currentWidth: CGFloat = 0
        var fullHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentWidth + size.width > width {
                currentWidth = 0
                fullHeight += rowHeight + spacing
                rowHeight = 0
            }

            currentWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(
            width: width,
            height: fullHeight + rowHeight // because we have at least one row
        )
    }
    
    
    
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {

        let rows = divideIntoRows(subviews, bounds)

        var y = bounds.minY

        for row in rows {
            let rowWidth = calculateRowWidth(row)
            let rowHeight = calculateRowHeight(row)

            var x = bounds.minX + (bounds.width - rowWidth) / 2 // Center the row

            for (subview, size) in row {
                subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )

                x += size.width + spacing
            }

            y += rowHeight + spacing
        }
    }
    
    fileprivate func divideIntoRows(_ subviews: FlowLayout.Subviews, _ bounds: CGRect) -> [[(LayoutSubview, CGSize)]] {
        var rows: [[(LayoutSubview, CGSize)]] = []
        var currentRow: [(LayoutSubview, CGSize)] = []
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            let proposedWidth =
            currentRow.isEmpty
            ? size.width
            : currentWidth + spacing + size.width
            
            if proposedWidth > bounds.width {
                rows.append(currentRow)
                currentRow = [(subview, size)]
                currentWidth = size.width
            } else {
                currentRow.append((subview, size))
                currentWidth = proposedWidth
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    fileprivate func calculateRowWidth(_ row: [(LayoutSubview, CGSize)]) -> CGFloat {
        let subViewWidthSum = row.map{$1.width}.reduce(0, +)
        let spacingSum = CGFloat(max(0, row.count - 1)) * spacing
        return subViewWidthSum + spacingSum
    }
    
    fileprivate func calculateRowHeight(_ row: [(LayoutSubview, CGSize)]) -> CGFloat {
        return row.map{$1.height}.max() ?? 0
    }
}
