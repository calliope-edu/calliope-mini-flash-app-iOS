//
//  SwiftUIGraph.swift
//  Calliope App
//
//  Created by itestra on 28.06.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        ZStack {
            Color.pink
            Button("Hello, SwiftUI!") {
                
            }
            .font(.title)
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("SwiftUI View")
    }
}
