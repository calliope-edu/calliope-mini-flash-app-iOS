//
//  ArcadeView.swift
//  Calliope App
//
//  Created by Calliope on 01.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct ArcadeView<viewModelType: ArcadeViewModelProtocol & ObservableObject>: View {
    let viewModel: viewModelType

    var body: some View {
        AdaptiveColumnLayout {
            VStack {
                Text("Game development with MakeCode Arcade")
                    .font(.custom("RobotoCondensed-Bold", size: 22, relativeTo: .title2))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("With MakeCode Arcade, you can create games for your Calliope mini and play them with an additional display or even a game console.")
                SizedBox(height: 8)
                Image("Arcade_Homescreen")
            }
        } right: {
            VStack {
                Image("editors_swift")
                SizedBox(height: 8)
                Button("Let's get started!") { viewModel.openArcadeButtonTapped() }
                    .buttonStyle(.pill)
            }
        }
    }
}

struct ArcadeView_Previews: PreviewProvider {
    static var previews: some View {
        ArcadeView(viewModel: PreviewArcadeViewModel()).previewInterfaceOrientation(.landscapeLeft)
        ArcadeView(viewModel: PreviewArcadeViewModel()).previewInterfaceOrientation(.portrait)
    }
}
