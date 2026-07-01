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
                Text("With MakeCode Arcade, you can create games for your Calliope mini and play them with an additional display or even a game console. The files can only be transferred via USB cable.").fontWeight(.bold)
                SizedBox(height: 8)
                Image("Arcade_Homescreen")
            }
        } right: {
            VStack {
                Image("editors_swift")
                SizedBox(height: 8)
                boxButton(label: "Let's go!", iconName: nil, action: {viewModel.openArcadeButtonTapped()}, backgroundColor: Color.calliopePink)
            }
        }
    }

    func boxButton(label: String, iconName: String?, action: @escaping () -> Void, backgroundColor: Color = Color.calliopeGreen) -> some View {
        return Button {
            action()
        } label: {
            HStack {
                Text(LocalizedStringKey(label))  // need the LocalizedStringKey, so it is translated to German
                if iconName != nil {
                    (Image(iconName!))
                        .resizable().scaledToFit().frame(width: 30, height: 30)
                }
            }
            .padding()
            .padding(.horizontal, 16)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(12)

        }
    }
}

struct ArcadeView_Previews: PreviewProvider {
    static var previews: some View {
        ArcadeView(viewModel: PreviewArcadeViewModel()).previewInterfaceOrientation(.landscapeLeft)
        ArcadeView(viewModel: PreviewArcadeViewModel()).previewInterfaceOrientation(.portrait)
    }
}
