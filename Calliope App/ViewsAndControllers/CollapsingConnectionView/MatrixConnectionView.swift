//
//  MatrixConnectionView.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct MatrixConnectionView: View {
    @State var usbEnabled = false

    var body: some View {
        ExpandablePanel {
            VStack(alignment: .leading) {
                HStack {
                    Text("Connect a Calliope mini!")
                        .font(.title)

                    Spacer()

                    Rectangle().opacity(0).frame(width: 40, height: 40)
                }.frame(maxWidth: 300)

                Toggle("Connect with cable", isOn: $usbEnabled).frame(maxWidth: 300).padding(.bottom, 8)

                if usbEnabled {
                    Button {

                    } label: {
                        Text("Select Calliope mini")  // need the LocalizedStringKey, so it is translated to German
                            .frame(width: 268)
                            .padding(16)
                            .background(Color.calliopeGreen)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    MatrixSwiftUIView().frame(maxWidth: 300, maxHeight: 300)

                    HStack {
                        Spacer()

                        Button {
                            // ...
                        } label: {
                            Image("liveviewconnect/connect_refresh")
                        }

                        Spacer()
                    }.frame(maxWidth: 300)

                }
            }
        }
    }
}

struct ExpandablePanel<Content: View>: View {
    @State private var isExpanded = false

    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {

            if isExpanded {
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
                    isExpanded.toggle()
                }
            } label: {
                if isExpanded {
                    Image(systemName: "xmark").resizable().scaledToFit().frame(width: 20, height: 20)
                } else {
                    Image("liveviewconnect/mini_mini")
                }
            }
            .padding()
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(isExpanded ? Color.calliopeYellow : Color.red)
            .clipShape(Circle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
    }
}

// TODO: Rename after the old Views are deleted
struct MatrixSwiftUIView: View {
    @State private var buttonStates = Array(repeating: false, count: 25)

    @State private var dragValue: Bool?
    @State private var visitedCells: Set<Int> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    let spacing: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let totalSpacing = spacing * 4
            let cellSize = (geometry.size.width - totalSpacing) / 5

            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                ForEach(0..<5) { row in
                    GridRow {
                        ForEach(0..<5) { col in
                            let index = row * 5 + col

                            Rectangle()
                                .fill(buttonStates[index] ? Color.calliopePink : .white)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .gesture(
                dragGesture(cellSize: cellSize)
            )
        }.padding()
            .background(Color.calliopeYellow.brightness(0.05))
    }

    func cellIndex(at point: CGPoint, cellSize: CGFloat) -> Int? {
        let column = Int(point.x / (cellSize + spacing))
        let row = Int(point.y / (cellSize + spacing))

        guard row >= 0, row < 5,
            column >= 0, column < 5
        else {
            return nil
        }

        return row * 5 + column
    }

    func dragGesture(cellSize: Double) -> some Gesture {
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard
                    let index = cellIndex(
                        at: value.location,
                        cellSize: cellSize
                    )
                else { return }

                if dragValue == nil {
                    // First touched cell
                    buttonStates[index].toggle()
                    dragValue = buttonStates[index]
                    visitedCells.insert(index)
                } else if !visitedCells.contains(index) {
                    // New cell while dragging
                    buttonStates[index] = dragValue!
                    visitedCells.insert(index)
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
        MatrixConnectionView().previewInterfaceOrientation(.landscapeLeft)
        MatrixConnectionView().previewInterfaceOrientation(.portrait)
    }
}
