//
//  MatrixConnectionView.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct MatrixConnectionView<ViewModelType: MatrixConnectionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModelType

    var body: some View {
        ZStack {
            ExpandablePanel(viewModel: viewModel) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Connect a Calliope mini!")
                            .font(.title3)
                        Spacer()
                        Rectangle().opacity(0).frame(width: 40, height: 40)  // To keep the closing button free
                    }.frame(maxWidth: 300)

                    Toggle("Connect with cable", isOn: $viewModel.isInUsbMode).frame(maxWidth: 300).padding(.bottom, 8)

                    if viewModel.isInUsbMode {
                        selectUSBCalliopeButton
                    } else {
                        bluetoothMenu
                    }
                }.frame(width: 250)
            }
        }
    }

    var selectUSBCalliopeButton: some View {
        Button {
            viewModel.startUsbConnect()
        } label: {
            Text(NSLocalizedString("Select Calliope mini", comment: ""))
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.calliopeGreen)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .fileImporter(isPresented: $viewModel.isFolderPickerPresented, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                viewModel.handleUSBFolderPicked(url)
            }
        }
    }

    var bluetoothMenu: some View {
        VStack {
            MatrixView(viewModel: viewModel)

            connectButton
        }
    }

    var connectButton: some View {
        HStack {
            Spacer()

//            BouncableView(trigger: viewModel.connectButtonBounceTrigger) {
                Button {
                    viewModel.connect()
                } label: {
                    ZStack {
                        if connectButtonBackgroundColor != nil {
                            RoundedRectangle(cornerRadius: 20).fill(connectButtonBackgroundColor!).frame(width: 150, height: 55)
                        }
                        let buttonSize = 55.0
                        connectButtonForegroundImage.frame(height: buttonSize)
                    }
                }
//            }

            Spacer()
        }.frame(width: .infinity)
    }

    var connectButtonForegroundImage: some View {
        switch viewModel.connectButtonState {
        case .initialized:
            return AnyView(Image("liveviewconnect/mini_refresh").resizable().scaledToFit())
        case .waitingForBluetooth:
            return AnyView(Image("liveviewconnect/bluetooth_disabled").resizable().scaledToFit())
        case .searching:
            return AnyView(
                animationView(
                    images: [
                        "AnimProgress/0001", "AnimProgress/0002", "AnimProgress/0003", "AnimProgress/0004", "AnimProgress/0005", "AnimProgress/0006",
                        "AnimProgress/0007", "AnimProgress/0008", "AnimProgress/0009", "AnimProgress/0010", "AnimProgress/0011", "AnimProgress/0012",
                        "AnimProgress/0013", "AnimProgress/0014", "AnimProgress/0015", "AnimProgress/0016", "AnimProgress/0017", "AnimProgress/0018",
                        "AnimProgress/0019", "AnimProgress/0020",
                    ],
                    frameRate: 5,
                )
            )
        case .notFoundRetry:
            return AnyView(Image("liveviewconnect/connect_refresh").resizable().scaledToFit())
        case .readyToConnect:
            return AnyView(Image("liveviewconnect/connect_0001").resizable().scaledToFit())
        case .connecting:
            return AnyView(
                animationView(
                    images: [
                        "liveviewconnect/connect_0001", "liveviewconnect/connect_0002", "liveviewconnect/connect_0003",
                        "liveviewconnect/connect_0004", "liveviewconnect/connect_0005", "liveviewconnect/connect_0006",
                        "liveviewconnect/connect_0007", "liveviewconnect/connect_0008", "liveviewconnect/connect_0009",
                        "liveviewconnect/connect_0010", "liveviewconnect/connect_0009", "liveviewconnect/connect_0008",
                        "liveviewconnect/connect_0007", "liveviewconnect/connect_0006", "liveviewconnect/connect_0005",
                        "liveviewconnect/connect_0004", "liveviewconnect/connect_0003", "liveviewconnect/connect_0002",
                        "liveviewconnect/connect_0001",
                    ],
                    frameRate: 20,
                )
            )
        case .readyToPlay:
            return AnyView(Image("liveviewconnect/mini_figur").resizable().scaledToFit())
        case .wrongProgram:
            return AnyView(Image("liveviewconnect/connect_failed").resizable().scaledToFit())
        }
    }

    func animationView(images: [String], frameRate: Double) -> some View {
        TimelineView(.animation) { timeline in
            let index =
                Int(timeline.date.timeIntervalSince1970 * frameRate)
                % images.count

            Image(images[index]).resizable().scaledToFit()
        }
    }

    var connectButtonBackgroundColor: Color? {
        switch viewModel.connectButtonState {
        case .initialized:
            return nil
        case .waitingForBluetooth:
            return nil
        case .searching:
            return nil
        case .notFoundRetry:
            return Color.calliopeRed
        case .readyToConnect:
            return Color.calliopeGreen
        case .connecting:
            return nil
        case .readyToPlay:
            return nil
        case .wrongProgram:
            return nil
        }
    }
}

struct BouncableView<Content: View>: View {
    let trigger: Int
    let scale: CGFloat
    let duration: Double
    @ViewBuilder let content: () -> Content

    @State private var bouncing = false

    init(
        trigger: Int,
        scale: CGFloat = 1.2,
        duration: Double = 0.3,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.trigger = trigger
        self.scale = scale
        self.duration = duration
        self.content = content
    }

    var body: some View {
        content()
            .scaleEffect(bouncing ? scale : 1.0)
            .animation(
                .easeInOut(duration: duration)
                    .repeatCount(2, autoreverses: true),
                value: bouncing
            )
            .onChange(of: trigger) { _ in
                bounce()
            }
    }

    private func bounce() {
        bouncing = false

        // Ensure SwiftUI sees a state transition
        DispatchQueue.main.async {
            bouncing = true
        }
    }
}

struct ExpandablePanel<Content: View, ViewModelType: MatrixConnectionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModelType
    @ObservedObject var uploadProgress = UploadProgressViewModel.instance
    @Namespace private var glassNamespace

    var connectionButtonSize: CGFloat = 50

    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {

            if viewModel.menuExpanded && !uploadProgress.isUploading {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            viewModel.menuExpanded = false
                        }
                    }
                    .ignoresSafeArea()
                VStack {
                    content()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.calliopeYellow)
                        .shadow(radius: 10)
                )
                .transition(
                    .scale(scale: 0.1, anchor: .topTrailing)
                        .combined(with: .opacity)
                )
            }

            // iOS 26+: place button and progress bar inside the same GlassEffectContainer
            // so the glass system morphs the circle → capsule when an upload starts.
            // Pre-iOS 26: keep the existing solid-colour fallback behaviour.
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    if uploadProgress.isUploading {
                        UploadProgressPanel(uploadProgress: uploadProgress, namespace: glassNamespace)
                    } else {
                        connectionMenuButtonGlass
                    }
                }
                .frame(maxWidth: 420, alignment: .trailing)
            } else {
                if uploadProgress.isUploading {
                    UploadProgressPanel(uploadProgress: uploadProgress, namespace: glassNamespace)
                        .modifier(GlassContainerModifier(namespace: glassNamespace))
                } else {
                    connectionMenuButton
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
        .animation(.spring(), value: uploadProgress.isUploading)
    }

    // MARK: - Connection Menu Button (normal state)

    var connectionMenuButton: some View {
//        BouncableView(trigger: viewModel.connectionMenuButtonBounceTrigger) {
            Button {
                withAnimation(.spring()) {
                    viewModel.menuExpanded.toggle()
                }
            } label: {
                if viewModel.menuExpanded {
                    Image(systemName: "xmark").resizable().scaledToFit().frame(width: 20, height: 20)
                } else {
                    menuButtonImage
                }
            }
            .padding()
            .foregroundColor(.white)
            .frame(width: connectionButtonSize, height: connectionButtonSize)
            .background(menuButtonColor)
            .clipShape(Circle())
//        }
    }

    // MARK: - Connection Menu Button (Liquid Glass variant, iOS 26+)
    // Shares glassEffectID("progressBar") with the progress bar so the system morphs
    // the circle into a capsule (and back) when an upload starts or finishes.

    @available(iOS 26.0, *)
    var connectionMenuButtonGlass: some View {
//        BouncableView(trigger: viewModel.connectionMenuButtonBounceTrigger) {
            if viewModel.menuExpanded {
                // X button: no background — it floats over the open menu panel.
                AnyView(
                Button {
                    withAnimation(.spring()) { viewModel.menuExpanded.toggle() }
                } label: {
                    Image(systemName: "xmark").resizable().scaledToFit().frame(width: 20, height: 20)
                }
                .padding()
                .foregroundColor(.white)
                .frame(width: connectionButtonSize, height: connectionButtonSize))
            } else {
                AnyView(
                // Normal state: liquid-glass circle that morphs into the progress bar on upload.
                Button {
                    withAnimation(.spring()) { viewModel.menuExpanded.toggle() }
                } label: {
                    menuButtonImage
                }
                .padding()
                .foregroundColor(.white)
                .frame(width: connectionButtonSize, height: connectionButtonSize)
                .glassEffect(.identity, in: .circle)
                .glassEffectID("progressBar", in: glassNamespace)
                .glassEffectTransition(.matchedGeometry)
                .background(menuButtonColor)
                .clipShape(Circle()))
            }
//        }
    }

    // MARK: - Menu Button Appearance

    var menuButtonColor: Color {
        if viewModel.menuExpanded {
            return Color.calliopeYellow
        }
        switch viewModel.connectionMenuButtonState {
        case .disabled:
            return Color.calliopeRed
        case .disconnected:
            return Color.calliopeRed
        case .connecting:
            return Color.calliopeRed
        case .connected:
            return Color.calliopeGreen
        case .transmitting:
            return Color.calliopeGreen
        }
    }

    var menuButtonImage: some View {
        let imageSize = 55.0
        switch viewModel.connectionMenuButtonState {
        case .disabled:
            return AnyView(Image("liveviewconnect/bluetooth_disabled").resizable().scaledToFit().frame(width: imageSize, height: imageSize))
        case .disconnected:
            return AnyView(Image("liveviewconnect/mini_mini").resizable().scaledToFit().frame(width: imageSize, height: imageSize))
        case .connecting:
            return AnyView(Image("liveviewconnect/connect").resizable().scaledToFit().frame(width: imageSize, height: imageSize))
        case .connected:
            return AnyView(Image("liveviewconnect/mini_mini").resizable().scaledToFit().frame(width: imageSize, height: imageSize))
        case .transmitting:
            return AnyView(Image("liveviewconnect/connect").resizable().scaledToFit().frame(width: imageSize, height: imageSize))  // TODO: Update as soon as we have the corresponding assets
        }
    }
}

struct MatrixPosition: Hashable {
    let row: Int
    let column: Int
}

struct MatrixView<ViewModelType: MatrixConnectionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModelType

    @State private var dragValue: Bool?
    @State private var visitedCells: Set<MatrixPosition> = []
    @State private var bouncingCells: [[Bool]] = Array(repeating: Array(repeating: false, count: 5), count: 5)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    let spacing: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let totalSpacing = spacing * 4
            let cellSize = (geometry.size.width - totalSpacing) / 5

            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                ForEach(0..<5) { row in
                    GridRow {
                        ForEach(0..<5) { column in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(cellColor(row: row, column: column))
                                .aspectRatio(1, contentMode: .fit)
                                .scaleEffect(bouncingCells[row][column] ? 1.05 : 1.0)
                                .animation(.spring(response: 0.15, dampingFraction: 0.35), value: bouncingCells[row][column])
                        }
                    }
                }
            }
            .gesture(
                dragGesture(cellSize: cellSize)
            )
        }.padding()
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.calliopeYellow)).brightness(0.05).aspectRatio(1, contentMode: .fit)
    }

    private func cellColor(row: Int, column: Int) -> Color {
        return viewModel.matrix[row][column] ? Color.calliopePink : .white
    }

    func cellMatrixPosition(at point: CGPoint, cellSize: CGFloat) -> MatrixPosition? {
        let column = Int(point.x / (cellSize + spacing))
        let row = Int(point.y / (cellSize + spacing))

        guard row >= 0, row < 5,
            column >= 0, column < 5
        else {
            return nil
        }

        return MatrixPosition(row: row, column: column)
    }

    /// Sets a cell and cascades: activation goes downward with a staggered bounce, deactivation clears the whole column.
    func setCell(at position: MatrixPosition, to value: Bool) {
        if value {
            // Activate this cell and all below, bouncing each in sequence
            let column = position.column
            for row in position.row..<5 {
                visitedCells.insert(MatrixPosition(row: row, column: column))
                let delay = Double(row - position.row) * 0.08
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    bouncingCells[row][column] = true
                    viewModel.matrix[row][column] = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        bouncingCells[row][column] = false
                    }
                }
            }
        } else {
            // Deactivate entire column, bouncing outward from the tapped cell
            let column = position.column
            for row in 0..<5 {
                visitedCells.insert(MatrixPosition(row: row, column: column))
                let delay = Double(abs(row - position.row)) * 0.08
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    bouncingCells[row][column] = true
                    viewModel.matrix[row][column] = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        bouncingCells[row][column] = false
                    }
                }
            }
        }
    }

    func dragGesture(cellSize: Double) -> some Gesture {
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard viewModel.matrixInteractionEnabled else { return }
                guard
                    let matrixPosition = cellMatrixPosition(
                        at: value.location,
                        cellSize: cellSize
                    )
                else { return }

                if dragValue == nil {
                    // First touched cell — toggle and cascade down the column
                    viewModel.matrix[matrixPosition.row][matrixPosition.column].toggle()
                    dragValue = viewModel.matrix[matrixPosition.row][matrixPosition.column]
                    setCell(at: matrixPosition, to: dragValue!)
                } else if !visitedCells.contains(matrixPosition) {
                    // New cell while dragging — set and cascade down the column
                    setCell(at: matrixPosition, to: dragValue!)
                }
            }
            .onEnded { _ in
                dragValue = nil
                visitedCells.removeAll()
            }
    }
}

// MARK: - Liquid Glass Modifiers with iOS 26+ availability

enum GlassShape {
    case capsule
    case circle
}

/// Wraps content in a GlassEffectContainer on iOS 26+
struct GlassContainerModifier: ViewModifier {
    var namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                content
            }
        } else {
            content
        }
    }
}

/// Applies glassEffect + glassEffectID on iOS 26+, solid fallback on older
struct GlassElementModifier: ViewModifier {
    var id: String
    var namespace: Namespace.ID
    var shape: GlassShape
    var tintColor: Color? = nil

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .capsule:
                if let tintColor {
                    content
                        .glassEffect(.regular.tint(tintColor).interactive(), in: .capsule)
                        .glassEffectID(id, in: namespace)
                        .glassEffectTransition(.matchedGeometry)
                } else {
                    content
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID(id, in: namespace)
                        .glassEffectTransition(.matchedGeometry)
                }
            case .circle:
                content
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID(id, in: namespace)
                    .glassEffectTransition(.matchedGeometry)
            }
        } else {
            switch shape {
            case .capsule:
                content.background(Capsule().fill(tintColor ?? Color.gray.opacity(0.3)))
            case .circle:
                content.background(Circle().fill(Color.gray.opacity(0.3)))
            }
        }
    }
}

#Preview("Whole Page") {
    MatrixConnectionView(viewModel: PreviewMatrixConnectionViewModel())
}

#Preview("Menu Button Variants") {
    ForEach(
        [
            ConnectionMenuButtonState.disabled, ConnectionMenuButtonState.disconnected, ConnectionMenuButtonState.connecting,
            ConnectionMenuButtonState.connected, ConnectionMenuButtonState.transmitting,
        ],
        id: \.self
    ) { connectionMenuButtonState in
        MatrixConnectionView(viewModel: PreviewMatrixConnectionViewModel(connectionMenuButtonState: connectionMenuButtonState))
    }
}

#Preview("Upload Transition") {
    struct UploadTransitionPreview: View {
        @ObservedObject var viewModel = PreviewMatrixConnectionViewModel()
        @State private var timer: Timer?

        var body: some View {
            ZStack {
                Color.gray.opacity(0.2).ignoresSafeArea()

                MatrixConnectionView(viewModel: viewModel)

                VStack {
                    Spacer()

                    if !UploadProgressViewModel.instance.isUploading {
                        Button("Start Upload") {
                            //                            withAnimation(.spring()) {
                            UploadProgressViewModel.instance.startUpload()
                            //                            }
                            // Simulate progress over 5 seconds
                            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
                                if UploadProgressViewModel.instance.progress < 1.0 {
                                    //                                    withAnimation {
                                    UploadProgressViewModel.instance.updateProgress(UploadProgressViewModel.instance.progress + 0.005)
                                    //                                    }
                                } else {
                                    t.invalidate()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        //                                        withAnimation(.spring()) {
                                        UploadProgressViewModel.instance.finishUpload()
                                        //                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.calliopeGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    } else {
                        Text("Uploading: \(Int(UploadProgressViewModel.instance.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 40)
            }
            .onDisappear {
                timer?.invalidate()
                UploadProgressViewModel.instance.finishUpload()
            }
        }
    }
    return UploadTransitionPreview()
}

#Preview("Connect Button Variants") {
    ForEach(
        [
            ConnectButtonState.initialized, ConnectButtonState.waitingForBluetooth, ConnectButtonState.searching, ConnectButtonState.notFoundRetry,
            ConnectButtonState.readyToConnect, ConnectButtonState.connecting, ConnectButtonState.readyToPlay, ConnectButtonState.wrongProgram,
        ],
        id: \.self
    ) { connectButtonState in
        MatrixConnectionView(viewModel: PreviewMatrixConnectionViewModel(connectButtonState: connectButtonState)).connectButton.background(
            Color.calliopeYellow
        )
    }
}

#Preview("On EditorsAndPrograms") {
    ZStack {
        EditorsAndProgramsView(viewModel: EditorsAndProgramsViewModel())
            .environmentObject(RootCoordinator())

        MatrixConnectionView(viewModel: PreviewMatrixConnectionViewModel())
            .offset(x: -8, y: 8)
    }
}
