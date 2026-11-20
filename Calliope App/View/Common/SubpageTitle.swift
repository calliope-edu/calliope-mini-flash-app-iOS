//
//  SubpageTitle.swift
//  Calliope App
//
//  Created by Calliope on 18.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

extension View {
    func subpageTitle(_ title: Text) -> some View {
        navigationTitle(title)
            .toolbar {
                // navigationTitle ignores textCase, so the uppercased title is shown as the principal item instead
                ToolbarItem(placement: .principal) {
                    title.textCase(.uppercase).font(.headline)
                }
            }
    }
}
