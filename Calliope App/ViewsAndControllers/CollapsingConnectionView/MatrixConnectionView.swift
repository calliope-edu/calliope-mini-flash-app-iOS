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
            MatrixSwiftUIView(matrix: $viewModel.matrix).frame(maxWidth: 300, maxHeight: 300)

            HStack {
                Spacer()

                Button {
                    viewModel.connect()
                } label: {
                    ZStack (alignment: .top){
                        if connectButtonBackgroundImage  != nil {
                            Image(connectButtonBackgroundImage!).resizable().scaledToFit().frame(maxWidth: 300)
                        }
                        if connectButtonForegroundImage != nil {
                            Image(connectButtonForegroundImage!).resizable().scaledToFit().frame(maxWidth: 300)
                        }
                    }.frame(maxWidth: 150)
                }

                Spacer()
            }.frame(maxWidth: 300)

        }
    }
    
    var connectButtonForegroundImage: String? {
        switch viewModel.connectButtonState {
        case .initialized:
           return "liveviewconnect/mini_refresh"
        case .waitingForBluetooth:
           return "lifeviewconnect/bluetooth_disabled"
        case .searching:
          return "AnimProgress/0001"
        case .notFoundRetry:
            return "liveviewconnect/connect_refresh"
        case .readyToConnect:
           return "liveviewconnect/connect_0001"
        case .connecting:
           return "liveviewconnect/connect_0001"
        case .readyToPlay:
           return "liveviewconnect/mini_figur"
        case .wrongProgram:
           return "liveviewconnect/connect_failed"
        }
    }
    
    var connectButtonBackgroundImage: String? {
        switch viewModel.connectButtonState {
        case .initialized:
            return nil
        case .waitingForBluetooth:
            return nil
        case .searching:
           return nil
        case .notFoundRetry:
           return "liveviewconnect/mini_button_red"
        case .readyToConnect:
           return "liveviewconnect/mini_button_green"
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
                    Image(menuButtonImage)
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
    
    var menuButtonImage: String {
        switch viewModel.connectionMenuButtonState {
        case .disabled:
            return "liveviewconnect/bluetooth_disabled"
        case .disconnected:
            return "liveviewconnect/mini_mini"
        case .connecting:
            return "liveviewconnect/connect"
        case .connected:
            return "liveviewconnect/mini_mini"
        case .transmitting:
            return "liveviewconnect/connect" // TODO: Update as soon as we have the corresponding assets
        }
    }
}

struct MatrixPosition: Hashable {
    let row: Int
    let column: Int
}

// TODO: Rename after the old Views are deleted
struct MatrixSwiftUIView: View {
    @Binding var matrix: [[Bool]]

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
                                .fill(matrix[row][column] ? Color.calliopePink : .white)
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
                guard
                    let matrixPosition = cellMatrixPosition(
                        at: value.location,
                        cellSize: cellSize
                    )
                else { return }

                if dragValue == nil {
                    // First touched cell
                    matrix[matrixPosition.row][matrixPosition.column].toggle()
                    dragValue = matrix[matrixPosition.row][matrixPosition.column]
                    visitedCells.insert(matrixPosition)
                } else if !visitedCells.contains(matrixPosition) {
                    // New cell while dragging
                    matrix[matrixPosition.row][matrixPosition.column] = dragValue!
                    visitedCells.insert(matrixPosition)
                }
            }
            .onEnded { _ in
                dragValue = nil
                visitedCells.removeAll()
            }
    }
}

struct MatrixConnectionView_Preview: PreviewProvider {
    static var previews: some View {
        let viewModel = PreviewMatrixConnectionViewModel()
        MatrixConnectionView(viewModel: viewModel).previewInterfaceOrientation(.landscapeLeft)
        MatrixConnectionView(viewModel: viewModel).previewInterfaceOrientation(.portrait)
    }
}
