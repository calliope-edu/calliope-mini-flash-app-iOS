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
    @EnvironmentObject private var uploadViewModel: UploadViewModel
    @Environment(\.connectionPanel) private var connectionPanel
    @Environment(\.settings) private var settings

    private var isEditorWebViewOpen: Bool {
        switch router.path.last {
        case .makeCode, .micropython, .openRobertaLab, .arcadeEditor, .makeCodeLink, .qrCodeToMakeCode:
            return true
        default:
            return false
        }
    }

    private let editorColumns = Array(repeating: GridItem(.flexible(), spacing: 20, alignment: .top), count: 3)

    var body: some View {
        NavigationStack(path: $router.path) {
            GeometryReader { geo in
                SwiftUI.Group {
                    if geo.size.width > 1000 {
                        HStack(alignment: .top, spacing: 16) {
                            editorsTile(centersGrid: true)
                                .padding(30)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .background(Color.calliopeLightgray, in: RoundedRectangle(cornerRadius: 12))
                                VStack(spacing: 16) {
                                    originalProgramTile(isLandscape: true)
                                    SizedBox(height:10)
                                    programsTile
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(30)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                editorsTile(centersGrid: false)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(30)
                                    .background(Color.calliopeLightgray, in: RoundedRectangle(cornerRadius: 12))
                                SwiftUI.Group {
                                    originalProgramTile(isLandscape: false)
                                    programsTile
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(30)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationDestination(for: EditorsAndProgramRoute.self) { route in
                switchRoutes(route: route)
            }
        }
        .modifier(AlertModifier(alert: viewModel.alertBinding))
        .toolbar(isEditorWebViewOpen ? .hidden : .automatic, for: .tabBar)
        .onAppear {
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
            PopupEditorWebView(editor: MakeCode(url: settings.makeCodeUrl), alertPublisher: viewModel)
        case .micropython:
            PopupEditorWebView(editor: MicroPython(url: settings.microPythonUrl), alertPublisher: viewModel)
        case .openRobertaLab:
            PopupEditorWebView(editor: RobertaEditor(url: settings.robertaUrl), alertPublisher: viewModel)
        case .calliopeMiniBlocks:
            CalliopeMiniBlocksView(viewModel: CalliopeMiniBlocksViewModel(uploadViewModel: uploadViewModel, connectionPanel: connectionPanel, settings: settings))
        case .arcadeLanding:
            ArcadeView(viewModel: ArcadeViewModel(openArcade: { router.push(.arcadeEditor) }))
        case .arcadeEditor:
            PopupEditorWebView(editor: ArcadeEditor(url: settings.arcadeUrl), alertPublisher: viewModel)
        case .makeCodeLink(let url):
            changeMakeCodeURL(url: url)
        case .qrCodeToMakeCode(let url):
            changeMakeCodeURL(url: url)
        }
    }

    func changeMakeCodeURL(url: String) -> PopupEditorWebView {
        let makeCode = MakeCode(url: URL(string: url) ?? settings.makeCodeUrl)
        return PopupEditorWebView(editor: makeCode, alertPublisher: viewModel)
    }

    func editorsTile(centersGrid: Bool) -> some View {
        VStack(alignment: .leading) {
            editorsHeader
            if centersGrid {
                Spacer(minLength: 0)
                editorsGrid
                Spacer(minLength: 0)
                // Invisible copy so the grid is centered in the whole column, not just below the header
                editorsHeader.hidden()
            } else {
                editorsGrid
            }
        }
    }

    var editorsHeader: some View {
        VStack(alignment: .leading) {
            Text("PROGRAMMING ENVIRONMENTS")
                .font(.title2)
            Text("Choose the editor you want to program your Calliope mini with.")
        }
    }

    var editorsGrid: some View {
        LazyVGrid(columns: editorColumns, spacing: 20) {
            ForEach(0..<viewModel.editors.count) { i in
                SwiftUI.Group {
                    if viewModel.editors[i].name == "Scan" {
                        EditorTile(config: viewModel.editors[i], infoText: NSLocalizedString("Open a program in MakeCode using a QR code. Simply scan it and off you go!", comment: ""))
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
                            case "Arcade":
                                router.push(.arcadeLanding)
                            default:
                                break
                            }
                        }
                    }
                }
                .anchorPreference(key: MakeCodeGroupBoundsKey.self, value: .bounds) { bounds in
                    ["Makecode", "Scan"].contains(viewModel.editors[i].name) ? [bounds] : []
                }
            }
        }
        .backgroundPreferenceValue(MakeCodeGroupBoundsKey.self) { anchors in
            GeometryReader { proxy in
                let rect = anchors.map { proxy[$0] }.reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -8, dy: -8)
                if !rect.isNull {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.06))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
    }

    func originalProgramTile(isLandscape: Bool) -> some View {
        VStack(alignment: .leading) {
            Text("TRANSFER START PROGRAM")
                .font(.title2)
            Text("Choose your Calliope mini version and transfer the start program to your connected Calliope mini.")
            SizedBox(height:10)
            HStack(alignment: .top, spacing: 16) {
                startProgramColumn(imageName: "startprogramm1+2", label: "Calliope mini 1+2", boxColor: Color.calliopeTurqoise, action: { viewModel.uploadDefaultV1And2Program() })
                startProgramColumn(imageName: "startprogramm3", label: "Calliope mini 3", boxColor: Color.calliopePink, action: { viewModel.uploadDefaultV3Program() })
            }
        }
    }

    func startProgramColumn(imageName: String, label: String, boxColor: Color, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 120)
                .padding()
                .background(boxColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            SizedBox(height:1)
            pillButton(label: label, action: action)
        }
        .frame(maxWidth: .infinity)
    }

    var programsTile: some View {
        VStack(alignment: .leading) {
            Text("TRANSFER PROGRAMS")
                .font(.title2)
            Text("Choose a program you want to share or transfer to your Calliope mini.")
            let hexFileType = UTType.init(filenameExtension: "hex")!
            SizedBox(height:10)
            pillButton(label: "Open File", action: { presentingFileImporter = true })
                .fileImporter(isPresented: $presentingFileImporter, allowedContentTypes: [hexFileType]) { result in
                    viewModel.openFile(result: result)
                    presentingFileImporter = false
                }
                .frame(maxWidth: .infinity)
        }
    }

    func pillButton(label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(LocalizedStringKey(label))  // need the LocalizedStringKey, so it is translated to German
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Color.calliopeGreen, in: Capsule())
                .foregroundColor(.white)
        }
    }
}

private struct MakeCodeGroupBoundsKey: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] = []

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value += nextValue()
    }
}

struct EditorTile: View {
    let config: EditorTileConfig
    var infoText: String? = nil

    var body: some View {
        VStack {
            if let infoText {
                iconBox.info(infoText)
            } else {
                iconBox
            }
            Text(config.name).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var iconBox: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(config.backgroundColor ?? Color.clear)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(config.iconName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(config.imageSize)
            }
            .frame(maxWidth: 130)
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
                .padding(6)
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
