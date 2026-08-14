//
//  MatrixConnectionView.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct MatrixConnectionView<ViewModelType: MatrixConnectionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModelType

    var body: some View {
        ZStack {
            ExpandablePanel(viewModel: viewModel) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Connect a Calliope mini!")
                            .font(.title)
                        Spacer()
                        Rectangle().opacity(0).frame(width: 40, height: 40)  // To keep the closing button free
                    }.frame(maxWidth: 300)

                    Toggle("Connect with cable", isOn: $viewModel.isInUsbMode).frame(maxWidth: 300).padding(.bottom, 8)

                    if viewModel.isInUsbMode {
                        selectUSBCalliopeButton
                    } else {
                        bluetoothMenu
                    }
                }
            }
        }
    }

    var selectUSBCalliopeButton: some View {
        Button {
            viewModel.startUsbConnect()
        } label: {
            Text("Select Calliope mini")  // need the LocalizedStringKey, so it is translated to German
                .frame(width: 268)
                .padding(16)
                .background(Color.calliopeGreen)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    var bluetoothMenu: some View {
        VStack {
            MatrixView(viewModel: viewModel).frame(maxWidth: 300, maxHeight: 300)

            connectButton
        }
    }

    var connectButton: some View {
        HStack {
            Spacer()

            BouncableView(trigger: viewModel.connectButtonBounceTrigger) {
                Button {
                    viewModel.connect()
                } label: {
                    ZStack {
                        if connectButtonBackgroundColor != nil {
                            RoundedRectangle(cornerRadius: 20).fill(connectButtonBackgroundColor!).frame(width: 200, height: 75)
                        }
                        connectButtonForegroundImage
                    }.frame(width: 150, height: 100)
                }
            }

            Spacer()
        }.frame(maxWidth: 300)
    }

    var connectButtonForegroundImage: some View {
        switch viewModel.connectButtonState {
        case .initialized:
            return AnyView(Image("liveviewconnect/mini_refresh").resizable().scaledToFit().frame(height: 100))
        case .waitingForBluetooth:
            return AnyView(Image("liveviewconnect/bluetooth_disabled").resizable().scaledToFit().frame(height: 65))
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
                    height: 60
                )
            )
        case .notFoundRetry:
            return AnyView(Image("liveviewconnect/connect_refresh").resizable().scaledToFit().frame(height: 100))
        case .readyToConnect:
            return AnyView(Image("liveviewconnect/connect_0001").resizable().scaledToFit().frame(height: 100))
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
                    height: 100
                )
            )
        case .readyToPlay:
            return AnyView(Image("liveviewconnect/mini_figur").resizable().scaledToFit().frame(height: 100))
        case .wrongProgram:
            return AnyView(Image("liveviewconnect/connect_failed").resizable().scaledToFit().frame(height: 100))
        }
    }

    func animationView(images: [String], frameRate: Double, height: Double) -> some View {
        TimelineView(.animation) { timeline in
            let index =
                Int(timeline.date.timeIntervalSince1970 * frameRate)
                % images.count

            Image(images[index]).resizable().scaledToFit().frame(height: height)
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

    // Two-stage expansion: stage 1 = background + progress bar (isExpanded),
    // stage 2 = buttons morph out (buttonsVisible), text fades in (textVisible)
    @State private var buttonsVisible: Bool = false
    @State private var textVisible: Bool = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

            if uploadProgress.isUploading {
                uploadProgressView
            } else {
                connectionMenuButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
        .animation(.spring(), value: uploadProgress.isUploading)
        .animation(.spring(duration: 0.55), value: uploadProgress.isExpanded)
        // Two-stage expansion: when isExpanded flips true, delay the buttons so the
        // background and progress bar finish animating first (stage 1), then morph
        // the buttons out of the progress bar (stage 2) with the text fading in after.
        .onChange(of: uploadProgress.isExpanded) { newValue in
            if newValue {
                // Stage 2 starts once the stage-1 spring (~0.55 s) has settled.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    guard uploadProgress.isExpanded else { return }
                    withAnimation(.spring(duration: 1.1)) {
                        buttonsVisible = true
                    }
                }
                // Text fades in mid-way through the button morph.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    guard uploadProgress.isExpanded else { return }
                    withAnimation(.easeOut(duration: 0.45)) {
                        textVisible = true
                    }
                }
            } else {
                withAnimation(.spring()) {
                    buttonsVisible = false
                    textVisible = false
                }
            }
        }
        .onAppear {
            // Sync local state if the view appears while already expanded
            if uploadProgress.isExpanded {
                buttonsVisible = true
                textVisible = true
            }
        }
    }

    // MARK: - Connection Menu Button (normal state)

    var connectionMenuButton: some View {
        BouncableView(trigger: viewModel.connectionMenuButtonBounceTrigger) {
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
            .frame(width: 60, height: 60)
            .background(menuButtonColor)
            .clipShape(Circle())
        }
    }

    // MARK: - Upload Progress View (single view, animates between compact and expanded)

    var uploadProgressView: some View {
        uploadProgressContent
            .modifier(GlassContainerModifier(namespace: glassNamespace))
            // On compact width (phone) the panel fills available space;
            // on regular width (iPad landscape) cap it at a sensible fixed size.
            .frame(maxWidth: horizontalSizeClass == .regular ? 420 : .infinity, alignment: .trailing)
    }

    var uploadProgressContent: some View {
        VStack(spacing: buttonsVisible ? 16 : 0) {
            // Stage 2: buttons morph out of the progress bar; text fades in afterwards.
            // This block is only shown after the background has finished expanding (stage 1).
            if buttonsVisible {
                HStack(alignment: .top) {
                    // Plain text – no liquid-glass background
                    Text(NSLocalizedString("Transferring to Calliope", comment: ""))
                        .font(.headline)
                        .foregroundColor(.black)
                        .opacity(textVisible ? 1 : 0)
                        .offset(y: textVisible ? 0 : -6)

                    Spacer()

                    // Cancel and X grouped together at trailing
                    HStack(spacing: 8) {
                        Button {
                            startCollapse { uploadProgress.cancel() }
                        } label: {
                            Text(NSLocalizedString("Cancel", comment: ""))
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .modifier(
                                    GlassElementModifier(
                                        id: "cancel",
                                        namespace: glassNamespace,
                                        shape: .capsule,
                                        tintColor: .calliopeRed
                                    )
                                )
                        }

                        Button {
                            startCollapse {
                                withAnimation(.spring(duration: 0.55)) {
                                    uploadProgress.isExpanded = false
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .resizable().scaledToFit()
                                .frame(width: 12, height: 12)
                                .padding(11)
                                .modifier(
                                    GlassElementModifier(
                                        id: "close",
                                        namespace: glassNamespace,
                                        shape: .circle
                                    )
                                )
                        }
                    }
                }
            }

            // Progress bar - always present, animates size
            Button {
                withAnimation(.spring()) {
                    uploadProgress.isExpanded.toggle()
                }
            } label: {
                progressBarContent
                    .frame(height: 40)
                    .modifier(
                        GlassElementModifier(
                            id: "progressBar",
                            namespace: glassNamespace,
                            shape: .capsule
                        )
                    )
            }
            .frame(maxWidth: uploadProgress.isExpanded ? .infinity : 200)
        }
        .padding(uploadProgress.isExpanded ? 20 : 0)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.calliopeYellow)
                .shadow(radius: 10)
                .opacity(uploadProgress.isExpanded ? 1 : 0)
        )
    }

    // MARK: - Collapse Animation (inverse of two-stage opening)

    // Sequences: text fades out → buttons merge into progress bar → `done()` is called.
    // For the X button, `done` collapses the background (stage 1 reverse).
    // For Cancel, `done` calls cancel() which removes the view entirely.
    private func startCollapse(done: @escaping () -> Void) {
        // Step 1: fade out the text first (mirror of the text-fade-in at the end of opening).
        withAnimation(.easeIn(duration: 0.25)) {
            textVisible = false
        }
        // Step 2: merge buttons back into the progress bar (mirror of stage 2).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(duration: 1.1)) {
                buttonsVisible = false
            }
        }
        // Step 3: execute the caller's action (collapse background or cancel).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            done()
        }
    }

    // MARK: - Progress Bar Content

    var progressBarContent: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.calliopeYellow)
                .brightness(0.05)

            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.calliopeGreen)
                    .frame(width: max(geometry.size.width * uploadProgress.progress, 0))
            }

            Text("\(Int(uploadProgress.progress * 100))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
        }
        .clipShape(Capsule())
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
        switch viewModel.connectionMenuButtonState {
        case .disabled:
            return AnyView(Image("liveviewconnect/bluetooth_disabled").resizable().scaledToFit().frame(width: 50, height: 50))
        case .disconnected:
            return AnyView(Image("liveviewconnect/mini_mini"))
        case .connecting:
            return AnyView(Image("liveviewconnect/connect"))
        case .connected:
            return AnyView(Image("liveviewconnect/mini_mini"))
        case .transmitting:
            return AnyView(Image("liveviewconnect/connect"))  // TODO: Update as soon as we have the corresponding assets
        }
    }
}

struct MatrixPosition: Hashable {
    let row: Int
    let column: Int
}

struct MatrixView<ViewModelType: MatrixConnectionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModelType

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
            .background(Color.calliopeYellow.brightness(0.05)).frame(width: 300, height: 300)
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
    func setCell(at position: MatrixPosition) {
        let column = position.column
        for row in position.row..<5 {
            let delay = Double(row - position.row) * 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                bouncingCells[row][column] = true
                viewModel.matrix[row][column] = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    bouncingCells[row][column] = false
                }
            }
        }
        for row in 0..<position.row {
            viewModel.matrix[row][column] = false
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
                setCell(at: matrixPosition)
            }
            .onEnded { _ in
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
