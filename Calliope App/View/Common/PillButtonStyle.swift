//
//  PillButtonStyle.swift
//  Calliope App
//
//  Created by Calliope on 20.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(isEnabled ? Color.calliopeDarkgreen : Color.calliopeGray, in: Capsule())
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
}
