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
    case arcadeLanding
    case arcadeEditor
    case makeCodeLink(url: String)
    case qrCodeToMakeCode(url: String)
}

struct EditorsAndProgramsView<viewModelType: EditorsAndProgramsViewModelProtocol & ObservableObject & Alertable>: View {
    @ObservedObject var viewModel: viewModelType
    @StateObject private var router = Router<EditorsAndProgramRoute>()
    @EnvironmentObject private var coordinator: RootCoordinator
    @State private var presentingFileImporter = false

    private var isEditorWebViewOpen: Bool {
        switch router.path.last {
        case .makeCode, .micropython, .openRobertaLab, .arcadeEditor, .makeCodeLink, .qrCodeToMakeCode:
            return true
        default:
            return false
        }
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            GeometryReader { geo in
                ScrollView {
                    if geo.size.width > 1000 {
                        // Landscape: original program tile full width on top, editors and programs side by side below
                        VStack(spacing: 16) {
                            originalProgramTile(isLandscape: true)
                                .tiled(color: Color.calliopeTurqoise, takeRemainingSpace: true, padding: 30)
                            HStack(alignment: .top, spacing: 16) {
                                editorsTile
                                    .tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                                    .fixedSize(horizontal: false, vertical: true)
                                programsTile
                                    .tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        // Portrait: all tiles stacked vertically
                        VStack(spacing: 16) {
                            originalProgramTile(isLandscape: false)
                                .tiled(color: Color.calliopeTurqoise, takeRemainingSpace: true, padding: 30)
                            editorsTile
                                .tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                                .fixedSize(horizontal: false, vertical: true)
                            programsTile
                                .tiled(color: Color.calliopeLightgray, takeRemainingSpace: true, padding: 30)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
            }
            .navigationDestination(for: EditorsAndProgramRoute.self) { route in
                switchRoutes(route: route)
            }
            .modifier(AlertModifier(alert: viewModel.alertBinding))
        }
        .toolbar(isEditorWebViewOpen ? .hidden : .automatic, for: .tabBar)
        .onAppear {
            MatrixConnectionViewModel.instance.calliopeClass = DiscoveredBLEDevice.self
            handlePendingEditorsRoute()
        }
        .onChange(of: coordinator.pendingEditorsRoute) { _ in
            handlePendingEditorsRoute()
        }
    }

    private func handlePendingEditorsRoute() {
        guard let route = coordinator.pendingEditorsRoute else {
            return
        }
        coordinator.pendingEditorsRoute = nil
        router.push(route)
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
        case .arcadeLanding:
            ArcadeView(viewModel: ArcadeViewModel(openArcade: { router.push(.arcadeEditor) }))
        case .arcadeEditor:
            PopupEditorWebView(editor: ArcadeEditor(), alertPublisher: viewModel)
        case .makeCodeLink(let url):
            changeMakeCodeURL(url: url)
        case .qrCodeToMakeCode(let url):
            changeMakeCodeURL(url: url)
        }
    }

    func changeMakeCodeURL(url: String) -> PopupEditorWebView {
        let makeCode = MakeCode()
        makeCode.url = URL(string: url) ?? makeCode.url
        return PopupEditorWebView(editor: makeCode, alertPublisher: viewModel)
    }

    var editorsTile: some View {
        VStack(alignment: .leading) {
            Text("You can program your Calliope mini with the help of the editors.").fontWeight(.bold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                ForEach(0..<viewModel.editors.count) { i in
                    if viewModel.editors[i].name == "Scan" {
                        EditorTile(config: viewModel.editors[i])
                            .info(NSLocalizedString("Open a program in MakeCode using a QR code. Simply scan it and off you go!", comment: ""))
                            .onTapGesture {
                                router.push(.qrCodeView)
                            }
                    } else {
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
                                router.push(.arcadeLanding)
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
    }

    func originalProgramTile(isLandscape: Bool) -> some View {
        VStack(alignment: .leading) {
            if isLandscape {
                Text("Download the original program for your Calliope mini. Connect your device and transfer the program!")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)

                HStack {
                    Image("demoa_01").resizable().scaledToFit().frame(maxWidth: 300).padding(.vertical, 10)
                    SizedBox(width: 100)
                    boxButton(label: "Calliope mini 1+2", iconName: "button_icon_upload", action: { viewModel.uploadDefaultV1And2Program() })
                    boxButton(label: "Calliope mini 3", iconName: "button_icon_upload", action: { viewModel.uploadDefaultV3Program() })

                }
            } else {
                HStack {
                    Spacer()
                    VStack {
                        Text("Download the original program for your Calliope mini. Connect your device and transfer the program!")
                            .fontWeight(.bold)
                            .foregroundStyle(Color.white)
                        Image("demoa_01").resizable().scaledToFit().frame(maxWidth: 300).padding(.vertical, 10)
                    }
                    Spacer()
                }

                HStack {
                    boxButton(label: "Calliope mini 1+2", iconName: "button_icon_upload", action: { viewModel.uploadDefaultV1And2Program() })
                    boxButton(label: "Calliope mini 3", iconName: "button_icon_upload", action: { viewModel.uploadDefaultV3Program() })

                }
            }
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
            let hexFileType = UTType.init(filenameExtension: "hex")!
            boxButton(label: "Open File", iconName: "doc", isSystemImage: true, action: { presentingFileImporter = true })
                .fileImporter(isPresented: $presentingFileImporter, allowedContentTypes: [hexFileType]) { result in
                    viewModel.openFile(result: result)
                    presentingFileImporter = false
                }
            SizedBox(height: 10)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
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
        HStack {
            VStack(alignment: .leading) {
                Text(config.name).foregroundStyle(Color.white)
                Text(config.lastUsed.formatted()).foregroundStyle(Color.white)
            }
            Spacer()
            Image("button_icon_upload")
                .resizable().scaledToFit().frame(maxWidth: 30)
                .onTapGesture {
                    editorsAndProgramsViewModel.downloadProgram(program: config)
                }
        }
        .frame(maxWidth: 250)
        .contentShape(Rectangle())
        .onTapGesture {
            showMenu = true
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in showMenu = true }
        )
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
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(config.backgroundColor != nil ? config.backgroundColor! : Color.clear)
                    .frame(width: 130, height: 130)
                Image(config.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: config.imageSize * 130, height: config.imageSize * 130)
            }
            Text(config.name).multilineTextAlignment(.center)
        }.frame(width: 150, height: 180, alignment: .top)
    }
}

struct EditorAndProgramsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PreviewEditorsAndProgramsViewModel()
        EditorsAndProgramsView(viewModel: viewModel).environmentObject(RootCoordinator()).previewInterfaceOrientation(.landscapeLeft)
        EditorsAndProgramsView(viewModel: viewModel).environmentObject(RootCoordinator()).previewInterfaceOrientation(.portrait)
    }
}

struct InfoModifier: ViewModifier {
    let helpText: String
    @State private var showHelp = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHelp.toggle()
                    }
                } label: {
                    Image(systemName: "info")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(.calliopePink, in: Circle())
                }
                .buttonStyle(.plain)
                // The padding is fine tuned for its currently only usage on the EditorAndPrograms page
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .popover(isPresented: $showHelp) {
                    Text(helpText)
                        .font(.body)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
    }
}

extension View {
    func info(_ helpText: String) -> some View {
        modifier(InfoModifier(helpText: helpText))
    }
}
