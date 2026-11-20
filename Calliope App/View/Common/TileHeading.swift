//
//  TileHeading.swift
//  Calliope App
//
//  Created by Calliope on 20.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

extension Text {
    func tileHeading() -> some View {
        font(.custom("RobotoCondensed-Bold", size: 22, relativeTo: .title2))
            .textCase(.uppercase)
    }
}
