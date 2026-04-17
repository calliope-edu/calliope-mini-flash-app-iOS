//
//  TilePageLayout.swift
//  Calliope App
//
//  Created by Calliope on 13.03.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct TilePageLayout<ItemType: HasTileItem>: View {
    @State private var orientation: Orientation = Orientation.landscape
    @State private var tileSize: CGSize = CGSize(width: 0, height: 0)
    
    let leftItem: ItemType
    let rightItems: [ItemType]
    let leftItemOnTap: (ItemType) -> Void
    let rightItemsOnTap: (ItemType) -> Void
    
    
    var body: some View {
        GeometryReader(content: self.updateGeometry).padding()
        
    }
    
    func updateGeometry(geometry: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            orientation = calculateOrientation(pageSize: geometry.size)
            tileSize = calculateTileSize(pageSize: geometry.size, orientation: orientation)
        }
        
        if orientation == .landscape {
            return AnyView(HStack(spacing: 16) {
                getStackContent(orientation: orientation, tileSize: tileSize)
            })
        } else {
            return AnyView(VStack(spacing: 16) {
                getStackContent(orientation: orientation, tileSize: tileSize)
            })
        }
    }

    func getStackContent(orientation: Orientation, tileSize: CGSize) -> some View {
        Group {
            Tile(tileItem: leftItem.tileItem, size: tileSize).onTapGesture {
                leftItemOnTap(leftItem)
            }
            TileGridView(tileSize: tileSize, orientation: orientation, items: rightItems) { selectedItem in
                rightItemsOnTap(selectedItem)
            }
        }
    }

    
    func calculateOrientation(pageSize: CGSize) -> Orientation {
        return pageSize.width > pageSize.height ? Orientation.landscape : Orientation.portrait
    }
    
    func calculateTileSize(pageSize: CGSize, orientation: Orientation) -> CGSize {
        var width = pageSize.width
        var height = pageSize.height
        if orientation == Orientation.landscape {
            width = width / 2
        }
        else {
            height = height / 2
        }
        
        let spacing: CGFloat = 8
        let widthRatio: CGFloat = 1.2
        
        if height * widthRatio < (width - spacing) {
            let height = height
            let width = height * widthRatio
            return CGSize(width: width, height: height)
        } else {
            let width = width - spacing
            let height = width / widthRatio
            return CGSize(width: width, height: height)
        }
    }
}


// MARK: – Grid view
struct TileGridView<ItemType: HasTileItem>: View {
    @State private var widthRatio: CGFloat = 1.2
    
    let tileSize: CGSize
    
    let orientation: Orientation
    
    let items: [ItemType]

    var onSelect: (ItemType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 0),
    ]

    var body: some View {
        ScrollView(orientation == Orientation.landscape ? Axis.Set.vertical : Axis.Set.horizontal) {
            if orientation == Orientation.portrait {
                LazyHGrid(rows: columns, spacing: 8) {
                    ForEach(items) { item in
                        Tile(tileItem: item.tileItem, size: tileSize)
                            .onTapGesture { onSelect(item) }
                    }
                }
                .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items) { item in
                        Tile(tileItem: item.tileItem, size: tileSize)
                            .onTapGesture { onSelect(item) }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Models
protocol HasTileItem: Identifiable {
    var id: UUID { get }
    var tileItem: TileItem { get }
}

extension HasTileItem {
    var id: UUID {
        return self.tileItem.id
    }
}

struct TileItem: Identifiable {
    let id = UUID()
    let title: String
    let imageName: String // name of an asset in the catalog
    let color: Color
}

enum Orientation {
    case landscape
    case portrait
}


// MARK: – Single cell
struct Tile: View {
    let tileItem: TileItem
    let size: CGSize
    
    var body: some View {
        VStack(spacing: 0) {
            Image(tileItem.imageName)
                .resizable()
                .scaledToFit()
                .padding(.vertical, 12)
            
            Rectangle()
                .fill(.white)
                .frame(height: 2)
                .padding(.horizontal, 12)
            
            TwoLineText(content: tileItem.title)
        }
        .frame(width: size.width, height: size.height)
        .background(tileItem.color)
        .cornerRadius(12)
    }
}

struct TwoLineText: View {
    let content: String
    
    var body: some View {
        Text("\n").font(.system(size: 30, weight: .regular))
                  .frame(maxWidth: .infinity)
                  .padding(12)
                .overlay(
                        Text(content).font(.system(size: 30, weight: .regular))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    , alignment: .center)
    }
}


// MARK: – Preview
struct TestTile: HasTileItem {
    let tileItem: TileItem
}

struct TilePageLayout_Previews: PreviewProvider {
    static var previews: some View {
        let leftItem = TestTile(tileItem: TileItem(title: "Left Tile", imageName: "info", color: Color("calliope-pink")))
        let rightItems = [
            TestTile(tileItem: TileItem(title: "Right Tile 1",    imageName: "facerobot", color: Color("calliope-lilablau"))),
            TestTile(tileItem: TileItem(title: "Right Tile 2",    imageName: "speak", color: Color("calliope-orange"))),
            TestTile(tileItem: TileItem(title: "Right Tile 3",    imageName: "control", color: Color("calliope-turqoise"))),
            TestTile(tileItem: TileItem(title: "Right Tile 4",    imageName: "teachablemachine", color: Color("calliope-darkgreen")))
        ]
        let callback: (TestTile) -> Void =  { testTile in
            LogNotify.log("Clicked on \(testTile.tileItem.title)")
        }
        TilePageLayout(leftItem: leftItem, rightItems: rightItems, leftItemOnTap: callback, rightItemsOnTap: callback)
    }
}


