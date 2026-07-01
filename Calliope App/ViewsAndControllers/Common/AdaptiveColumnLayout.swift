//
//  Untitled.swift
//  Calliope App
//
//  Created by Calliope on 01.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct AdaptiveColumnLayout<Left: View, Right: View>: View {
    var spacing: CGFloat = 20
    var minimumTwoColumnWidth: CGFloat = 700

    @ViewBuilder var left: Left
    @ViewBuilder var right: Right

    var body: some View {
        GeometryReader { geometry in
            let useTwoColumns =
                geometry.size.width >= minimumTwoColumnWidth && geometry.size.width > geometry.size.height

            if useTwoColumns {
                twoColumnLayout(geometry: geometry)
            } else {
                oneColumnLayout(geometry: geometry)
            }
        }
    }

    func twoColumnLayout(geometry: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: spacing) {
            ScrollView {
                left.frame(maxWidth: .infinity).frame(
                    minHeight: geometry.size.height - 16,
                    alignment: .center
                )
                .padding(8)
            }.scrollBounceBehavior(.basedOnSize)
                .background(Color.calliopeLightgray)
            ScrollView {
                right.frame(maxWidth: .infinity).frame(
                    minHeight: geometry.size.height - 16,
                    alignment: .center
                )
                .padding(8)
            }.scrollBounceBehavior(.basedOnSize)
        }
    }

    func oneColumnLayout(geometry: GeometryProxy) -> some View {
        GeometryReader { geometry in
            ScrollView {
                    VStack {
                        left.padding(8)
                        Divider()
                        right.padding(8)

                    }.frame(minHeight: geometry.size.height, alignment: .center)
            }.scrollBounceBehavior(.basedOnSize)

        }
    }
}
