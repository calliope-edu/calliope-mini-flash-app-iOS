//
//  CalliopeMiniBlocksView.swift
//  Calliope App
//
//  Created by Calliope on 01.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct CalliopeMiniBlocksView<viewModelType: CalliopeMiniBlocksViewModelProtocol & ObservableObject>: View {
    @ObservedObject var viewModel: viewModelType

    var body: some View {
        VStack {
            AdaptiveColumnLayout {
                VStack {
                    Text("Program your Calliope mini with Scratch!").fontWeight(.bold)
                    HStack {
                        Image("num_01_red").resizable().scaledToFit().frame(maxHeight: 35)
                        Text("Connect your calliope mini with the iPad.")
                    }
                    Image("blr_03").resizable().scaledToFit().frame(maxHeight: 65)
                    SizedBox(height: 16)

                    HStack {
                        Image("num_02_red").resizable().scaledToFit().frame(maxHeight: 35)
                        Text("First transfer the Scratch program to your Calliope mini to run the Scratch programs directly.")
                    }
                    HStack {
                        boxButton(label: "BlocksV2.hex", iconName: "button_icon_upload", action: { viewModel.uploadBlocksV2Program() })

                        boxButton(label: "BlocksV3.hex", iconName: "button_icon_upload", action: { viewModel.uploadBlocksV3Program() })
                    }
                    SizedBox(height: 16)

                    HStack {
                        Image("num_03_red").resizable().scaledToFit().frame(maxHeight: 35)
                        Text("Load the Calliope mini Blocks app from the app store and get started!")
                    }
                    Image("editors_blocks_rounded").resizable().scaledToFit().frame(maxHeight: 150).onTapGesture {
                        viewModel.openLinkToAppStorePage()
                    }
                    Image("app_store_badge").resizable().scaledToFit().frame(maxHeight: 75).onTapGesture {
                        viewModel.openLinkToAppStorePage()
                    }
                }
            } right: {
                VStack {
                    Image("editors_blocks_transparent").resizable().scaledToFit().frame(maxHeight: 150)
                    Text(
                        "An introduction to Scratch programming with the Calliope mini Blocks app, instructions and project ideas can be found on the website."
                    ).multilineTextAlignment(.center)
                    boxButton(
                        label: "Let's get started!",
                        iconName: nil,
                        action: { viewModel.openLinkToCalliopeBlocksGetStatedPage() },
                        backgroundColor: Color.calliopePink
                    )
                    SizedBox(height: 16)
                    Text(
                        "Scratch is a project of the Scratch Foundation, in collaboration with the Lifelong Kidergarden Group at the MIT Media Lab. It is available for free at https://scratch.mit.edu."
                    ).font(.system(size: 12)).multilineTextAlignment(.center)
                }
            }
        }.modifier(
            AlertModifier(alert: viewModel.alertBinding)
        )
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

struct SizedBox: View {
    let width: Double?
    let height: Double?

    init(width: Double? = nil, height: Double? = nil) {
        self.width = width
        self.height = height
    }

    var body: some View {
        Color.clear
            .frame(width: width ?? .infinity, height: height ?? .infinity)
    }
}

struct CalliopeMiniBlocksView_Previews: PreviewProvider {
    static var previews: some View {
        CalliopeMiniBlocksView(viewModel: PreviewCalliopeMiniBlocksViewModel())
    }
}
