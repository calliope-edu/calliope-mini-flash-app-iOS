//
//  EditorsAndProgramsView.swift
//  Calliope App
//
//  Created by Calliope on 19.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct EditorsAndProgramsView: View {
    @ObservedObject var viewModel: EditorsAndProgramsViewModel
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 500))]) {
                editorsTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                originalProgramCalliope3Tile.tiled(color: Color.calliopeTurqoise, takeRemainingSpace: true, padding: 30)
                originalProgramCalliope12Tile.tiled(color: Color.calliopePink, takeRemainingSpace: true, padding: 30)
                makeCodeQRCodeTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                fileToCalliopeTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                programsTile.tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
            }.frame(maxWidth: .infinity)
        }.padding()
    }

    var editorsTile: some View {
        VStack(alignment: .leading) {
            Text("You can program your Calliope mini with the help of the editors.").fontWeight(.bold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))]) {
                ForEach(0..<viewModel.editors.count) { i in
                    EditorTile(name: viewModel.editors[i])
                }
            }
        }
    }

    var originalProgramCalliope3Tile: some View {
        VStack(alignment: .leading) {
            Text("Calliope mini 3: Download the original program of the Calliope mini 3. Connect and transfer the program!").fontWeight(.bold)
            boxButton(label: "Start program", action: { print("Start Calliop mini 3 program")})
        }
    }

    var originalProgramCalliope12Tile: some View {
        VStack(alignment: .leading) {
            Text("Calliope mini 1+2: Download the original program of the Calliope mini 1 and Calliope mini 2. Connect and transfer the program!").fontWeight(.bold)
            boxButton(label: "Start program", action: { print("Start Calliop mini 1+2 program")})
        }
    }

    var makeCodeQRCodeTile: some View {
        VStack(alignment: .leading) {
            Text("Open a program in MakeCode using a QR code. Simply scan it and off you go!").fontWeight(.bold)
            boxButton(label: "Scan", action: { print("Scan QR Code")})
        }
    }

    var fileToCalliopeTile: some View {
        VStack(alignment: .leading) {
            Text("Transfer program from your iPhone or iPad directly to your Calliope mini or save them in your Calliope mini folder.").fontWeight(.bold)
            boxButton(label: "Choose File", action: { print("Choose file")})
        }
    }

    var programsTile: some View {
        VStack(alignment: .leading) {
            Text("A long press takes you to the option of transfering, sharing and deleting your programs stored in the Calliope mini folder.").fontWeight(.bold)
        }
    }
    
    func boxButton(label: String, action: @escaping () -> Void) -> some View {
        return Button {
            action()
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.calliopeGreen)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
}

struct EditorTile: View {
    let name: String
    
    var body: some View {
        Text(name)
    }
}

struct EditorAndProgramsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = EditorsAndProgramsViewModel()
        EditorsAndProgramsView(viewModel: viewModel)
    }
}
