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
            MatrixSwiftUIView(viewModel: viewModel).frame(maxWidth: 300, maxHeight: 300)

            connectButton
        }
    }

    var connectButton: some View {
        HStack {
            Spacer()

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
            return AnyView(animationView(images: ["AnimProgress/0001", "AnimProgress/0002", "AnimProgress/0003", "AnimProgress/0004", "AnimProgress/0005", "AnimProgress/0006", "AnimProgress/0007", "AnimProgress/0008", "AnimProgress/0009", "AnimProgress/0010", "AnimProgress/0011", "AnimProgress/0012", "AnimProgress/0013", "AnimProgress/0014", "AnimProgress/0015", "AnimProgress/0016", "AnimProgress/0017", "AnimProgress/0018", "AnimProgress/0019", "AnimProgress/0020"], frameRate: 5, height: 60))
        case .notFoundRetry:
            return AnyView(Image("liveviewconnect/connect_refresh").resizable().scaledToFit().frame(height: 100))
        case .readyToConnect:
            return AnyView(Image("liveviewconnect/connect_0001").resizable().scaledToFit().frame(height: 100))
        case .connecting:
            return AnyView(animationView(images: ["liveviewconnect/connect_0001", "liveviewconnect/connect_0002", "liveviewconnect/connect_0003", "liveviewconnect/connect_0004", "liveviewconnect/connect_0005", "liveviewconnect/connect_0006", "liveviewconnect/connect_0007", "liveviewconnect/connect_0008", "liveviewconnect/connect_0009", "liveviewconnect/connect_0010", "liveviewconnect/connect_0009", "liveviewconnect/connect_0008", "liveviewconnect/connect_0007", "liveviewconnect/connect_0006", "liveviewconnect/connect_0005", "liveviewconnect/connect_0004", "liveviewconnect/connect_0003", "liveviewconnect/connect_0002", "liveviewconnect/connect_0001"], frameRate: 20, height: 100))
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

struct ExpandablePanel<Content: View, ViewModelType: MatrixConnectionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModelType

    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if viewModel.menuExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            viewModel.menuExpanded = false
                        }
                    }
                    .ignoresSafeArea()
            }

            if viewModel.menuExpanded {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
    }

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
            return AnyView(Image("liveviewconnect/connect"))  // TODO: Update as soon as we have the corresponding assets
        }
    }
}

struct MatrixPosition: Hashable {
    let row: Int
    let column: Int
}

// TODO: Rename after the old Views are deleted
struct MatrixSwiftUIView<ViewModelType: MatrixConnectionViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModelType

    @State private var dragValue: Bool?
    @State private var visitedCells: Set<MatrixPosition> = []

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
                            Rectangle()
                                .fill(viewModel.matrix[row][column] ? Color.calliopePink : .white)
                                .aspectRatio(1, contentMode: .fit)
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
                    // First touched cell
                    viewModel.matrix[matrixPosition.row][matrixPosition.column].toggle()
                    dragValue = viewModel.matrix[matrixPosition.row][matrixPosition.column]
                    visitedCells.insert(matrixPosition)
                } else if !visitedCells.contains(matrixPosition) {
                    // New cell while dragging
                    viewModel.matrix[matrixPosition.row][matrixPosition.column] = dragValue!
                    visitedCells.insert(matrixPosition)
                }
            }
            .onEnded { _ in
                dragValue = nil
                visitedCells.removeAll()
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
