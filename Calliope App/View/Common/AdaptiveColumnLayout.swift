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
                .background(Color.calliopeLightgray.ignoresSafeArea())
            ScrollView {
                right.frame(maxWidth: .infinity).frame(
                    minHeight: geometry.size.height - 16,
                    alignment: .center
                )
                .padding(8)
            }.scrollBounceBehavior(.basedOnSize)
                .background(Color.white.ignoresSafeArea())
        }
    }

    func oneColumnLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            // Color the safe area at the top and the bottom in gray and white
            VStack(spacing: 0) {
                Color.calliopeLightgray.ignoresSafeArea(edges: .top)
                Color.white.ignoresSafeArea(edges: .bottom)
            }
            ScrollView {
                VStack(spacing: 0) {
                    left
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.calliopeLightgray)
                    right
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                }
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
