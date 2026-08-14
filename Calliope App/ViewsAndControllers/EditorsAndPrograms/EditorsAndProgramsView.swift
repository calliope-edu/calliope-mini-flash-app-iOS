//
//  EditorsAndProgramsView.swift
//  Calliope App
//
//  Created by Calliope on 19.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum EditorsAndProgramRoute: Hashable {
    case qrCodeView
    case makeCode
    case micropython
    case openRobertaLab
    case calliopeMiniBlocks
    case arcade
    case qrCodeToMakeCode(url: String)
}

struct EditorsAndProgramsView<viewModelType: EditorsAndProgramsViewModelProtocol & ObservableObject & Alertable>: View {
    @ObservedObject var viewModel: viewModelType
    @StateObject private var router = Router<EditorsAndProgramRoute>()
    @State private var presentingFileImporter = false

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                GeometryReader { geo in
                    ScrollView {
                        if geo.size.width > 1000 {
                            MasonryLayout(columns: 2) {
                                items
                            }
                        } else {
                            MasonryLayout(columns: 1) {
                                items
                            }
                        }
                    }
                    .padding()
                }

                MatrixConnectionView(viewModel: MatrixConnectionViewModel.instance)
            }.modifier(
                AlertModifier(alert: viewModel.alertBinding)
            )
            .navigationDestination(for: EditorsAndProgramRoute.self) { route in
                switchRoutes(route: route)
            }
        }.onAppear{
            MatrixConnectionViewModel.instance.calliopeClass = DiscoveredBLEDevice.self
        }
    }

    @ViewBuilder
    func switchRoutes(route: EditorsAndProgramRoute) -> some View {
        switch route {
        case .qrCodeView:
            QRCodeView { url in router.push(.qrCodeToMakeCode(url: url)) }
        case .makeCode:
            PopupEditorWebView(editor: MakeCode(), alertPublisher: viewModel)
        case .micropython:
            PopupEditorWebView(editor: MicroPython(), alertPublisher: viewModel)
        case .openRobertaLab:
            PopupEditorWebView(editor: RobertaEditor(), alertPublisher: viewModel)
        case .calliopeMiniBlocks:
            CalliopeMiniBlocksView(viewModel: CalliopeMiniBlocksViewModel())
        case .arcade:
            ArcadeView(viewModel: ArcadeViewModel(openArcade: {}))
        case .qrCodeToMakeCode(let url):
            changeMakeCodeURL(url: url)
        }
    }

    func changeMakeCodeURL(url: String) -> PopupEditorWebView {
        let makeCode = MakeCode()
        makeCode.url = URL(string: url) ?? makeCode.url
        return PopupEditorWebView(editor: makeCode, alertPublisher: viewModel)
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 40) {
                ForEach(0..<viewModel.editors.count) { i in
                    EditorTile(config: viewModel.editors[i]).onTapGesture {
                        switch viewModel.editors[i].name {
                        case "Makecode":
                            router.push(.makeCode)
                        case "Open Roberta Lab":
                            router.push(.openRobertaLab)
                        case "Calliope mini Blocks":
                            router.push(.calliopeMiniBlocks)
                        case "Micropython":
                            router.push(.micropython)
                        case "Arcade (USB only)":
                            router.push(.arcade)
                        default:
                            break
                        }
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
            boxButton(label: "Start Program", iconName: "button_icon_upload", action: { viewModel.uploadDefaultV1And2Program() })
        }
    }

    var makeCodeQRCodeTile: some View {
        VStack(alignment: .leading) {
            Text("Open a program in MakeCode using a QR code. Simply scan it and off you go!").fontWeight(.bold)
            boxButton(label: "Scan", iconName: "qr_code_scan_button", action: { router.push(.qrCodeView) })
        }
    }

    var fileToCalliopeTile: some View {
        VStack(alignment: .leading) {
            Text("Transfer program from your iPhone or iPad directly to your Calliope mini or save them in your Calliope mini folder.").fontWeight(
                .bold
            )
            let hexFileType = UTType.init(filenameExtension: "hex")!
            boxButton(label: "Choose File", iconName: "doc", isSystemImage: true, action: { presentingFileImporter = true })
                .fileImporter(isPresented: $presentingFileImporter, allowedContentTypes: [hexFileType]) { result in
                    viewModel.openFile(result: result)
                    presentingFileImporter = false
                }
        }
    }

    var programsTile: some View {
        VStack(alignment: .leading) {
            Text("Select a program to transfer, share, rename or delete it.")
                .fontWeight(.bold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: 40) {
                ForEach(viewModel.programs) { config in
                    ProgramTile(config: config, editorsAndProgramsViewModel: viewModel)
                        .tiled(color: Color.calliopeGray)
                }
            }
        }
    }

    func boxButton(label: String, iconName: String, isSystemImage: Bool = false, action: @escaping () -> Void) -> some View {
        return Button {
            action()
        } label: {
            HStack {
                Text(LocalizedStringKey(label))  // need the LocalizedStringKey, so it is translated to German
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

struct ProgramTile<viewModelType: EditorsAndProgramsViewModelProtocol & ObservableObject>: View {
    let config: ProgramTileConfig
    let editorsAndProgramsViewModel: viewModelType
    @State var showMenu = false

    var body: some View {
        Button(action: { showMenu = true }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(config.name).foregroundStyle(Color.white)
                    Text(config.lastUsed.formatted()).foregroundStyle(Color.white)
                }
                Spacer()
                Image("button_icon_upload").resizable().scaledToFit().frame(maxWidth: 30)
            }.frame(maxWidth: 250)
        }
        .confirmationDialog(
            "",
            isPresented: $showMenu,
            titleVisibility: .visible
        ) {
            Button("Transfer", systemImage: "arrow.left.arrow.right") { editorsAndProgramsViewModel.downloadProgram(program: config) }
            ShareLink("Share", item: config.hexFile.url)
            Button("Rename", systemImage: "rectangle.and.pencil.and.ellipsis") { editorsAndProgramsViewModel.renameProgram(program: config) }
            Button("Delete", systemImage: "trash", role: .destructive) { editorsAndProgramsViewModel.deleteProgram(program: config) }
        }
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
        }.frame(width: 150, height: 150)
    }
}

struct EditorAndProgramsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PreviewEditorsAndProgramsViewModel()
        EditorsAndProgramsView(viewModel: viewModel).previewInterfaceOrientation(.landscapeLeft)
        EditorsAndProgramsView(viewModel: viewModel).previewInterfaceOrientation(.portrait)
    }
}
