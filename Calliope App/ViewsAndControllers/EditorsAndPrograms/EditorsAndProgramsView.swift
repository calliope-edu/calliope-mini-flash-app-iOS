//
//  EditorsAndProgramsView.swift
//  Calliope App
//
//  Created by Calliope on 19.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct EditorsAndProgramsView<viewModelType: EditorsAndProgramsViewModelProtocol & ObservableObject>: View {
    @ObservedObject var viewModel: viewModelType

    var body: some View {

        GeometryReader { geo in
            ScrollView {
                if geo.size.width > 1000 {
                    TwoColumnLayout {
                        items
                    }
                } else {
                    OneColumnLayout {
                        items
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    var items: some View {
        editorsTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
        programsTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
        makeCodeQRCodeTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
        fileToCalliopeTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
        originalProgramCalliope3Tile.tiled(color: Color.calliopeTurqoise, takeRemainingSpace: true, padding: 30)
        originalProgramCalliope12Tile.tiled(color: Color.calliopePink, takeRemainingSpace: true, padding: 30)
    }

    var editorsTile: some View {
        VStack(alignment: .leading) {
            Text("You can program your Calliope mini with the help of the editors.").fontWeight(.bold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: 40) {
                ForEach(0..<viewModel.editors.count) { i in
                    EditorTile(config: viewModel.editors[i]).onTapGesture {
                        viewModel.openEditor(editor: viewModel.editors[i])
                    }
                }
            }
        }
    }

    var originalProgramCalliope3Tile: some View {
        VStack(alignment: .leading) {
            Text("Calliope mini 3: Download the original program of the Calliope mini 3. Connect and transfer the program!").fontWeight(.bold)
                .foregroundStyle(Color.white)
            HStack {
                Spacer()
                Image("startprogramm3").resizable().scaledToFit().frame(maxWidth: 300)
                Spacer()
            }.padding(.vertical, 16)
            boxButton(label: "Start program", iconName: "button_icon_upload", action: { viewModel.uploadDefaultV3Program() })
        }
    }

    var originalProgramCalliope12Tile: some View {
        VStack(alignment: .leading) {
            Text("Calliope mini 1+2: Download the original program of the Calliope mini 1 and Calliope mini 2. Connect and transfer the program!")
                .fontWeight(.bold).foregroundStyle(Color.white)
            HStack {
                Spacer()
                Image("startprogramm1+2").resizable().scaledToFit().frame(maxWidth: 300)
                Spacer()
            }.padding(.vertical, 16)
            boxButton(label: "Start program", iconName: "button_icon_upload", action: { viewModel.uploadDefaultV1And2Program() })
        }
    }

    var makeCodeQRCodeTile: some View {
        VStack(alignment: .leading) {
            Text("Open a program in MakeCode using a QR code. Simply scan it and off you go!").fontWeight(.bold)
            boxButton(label: "Scan", iconName: "qr_code_scan_button", action: { viewModel.scanQRCode() })
        }
    }

    var fileToCalliopeTile: some View {
        VStack(alignment: .leading) {
            Text("Transfer program from your iPhone or iPad directly to your Calliope mini or save them in your Calliope mini folder.").fontWeight(
                .bold
            )
            boxButton(label: "Choose File", iconName: "doc", isSystemImage: true, action: { viewModel.openFile() })
        }
    }

    var programsTile: some View {
        VStack(alignment: .leading) {
            Text("A long press takes you to the option of transfering, sharing and deleting your programs stored in the Calliope mini folder.")
                .fontWeight(.bold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: 40) {
                ForEach(0..<viewModel.programs.count) { i in
                    ProgramTile(config: viewModel.programs[i]).tiled(color: Color.calliopeGray).onTapGesture {
                        viewModel.downloadProgram(program: viewModel.programs[i])
                    }
                }
            }
        }
    }

    func boxButton(label: String, iconName: String, isSystemImage: Bool = false, action: @escaping () -> Void) -> some View {
        return Button {
            action()
        } label: {
            HStack {
                Text(label)
                Spacer()
                (isSystemImage ? Image(systemName: iconName) : Image(iconName))
                    .resizable().scaledToFit().frame(width: 30, height: 30)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.calliopeGreen)
            .foregroundColor(.white)
            .cornerRadius(12)

        }
    }
}

struct OneColumnLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        MasonryLayout(columns: 1) {
            content
        }
    }
}

struct TwoColumnLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        MasonryLayout(columns: 2) {
            content
        }
    }
}

struct ProgramTile: View {
    let config: ProgramTileConfig

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(config.name).foregroundStyle(Color.white)
                Text(config.lastUsed.formatted()).foregroundStyle(Color.white)
            }
            Spacer()
            Image("button_icon_upload").resizable().scaledToFit().frame(maxWidth: 30)
        }.frame(maxWidth: 250)
    }
}

struct EditorTile: View {
    let config: EditorTileConfig

    var body: some View {
        VStack {
            Image(config.iconName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 175)
            Text(config.name)
        }
    }
}

struct EditorAndProgramsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PreviewEditorsAndProgramsViewModel()
        EditorsAndProgramsView(viewModel: viewModel).previewInterfaceOrientation(.landscapeLeft)
        EditorsAndProgramsView(viewModel: viewModel).previewInterfaceOrientation(.portrait)
    }
}
