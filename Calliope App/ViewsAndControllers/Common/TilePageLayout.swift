//
//  TilePageLayout.swift
//  Calliope App
//
//  Created by Calliope on 13.03.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

class TileData<ItemType: HasTileItem>: ObservableObject {
    @Published var rightItems: [ItemType] = []
    
    init(rightItems: [ItemType]) {
        self.rightItems = rightItems
    }
}

struct TilePageLayout<ItemType: HasTileItem>: View {
    @State private var orientation: Orientation = Orientation.landscape
    @State private var tileSize: CGSize = CGSize(width: 0, height: 0)
    
    let leftItem: ItemType
    @ObservedObject var data: TileData<ItemType>
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
            TileGridView(tileSize: tileSize, orientation: orientation, items: data.rightItems) { selectedItem in
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
        if items.count == 1 {
            if orientation == .landscape {
                VStack {
                    Spacer()
                    gridContent
                    Spacer()
                }
            } else {
                HStack {
                    Spacer()
                    gridContent
                    Spacer()
                }
            }
        } else {
            ScrollView(orientation == .landscape ? .vertical : .horizontal) {
                Group {
                    if orientation == .portrait {
                        LazyHGrid(rows: columns, spacing: 8) {
                            gridContent
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            gridContent
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    @ViewBuilder
    private var gridContent: some View {
        ForEach(items) { item in
            Tile(tileItem: item.tileItem, size: tileSize)
                .onTapGesture { onSelect(item) }
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
    let imageSource: ImageSource
    let color: Color
    let textColor: Color
}

enum Orientation {
    case landscape
    case portrait
}

enum ImageSource {
    case remote(URL)
    case local(String) // asset name
}

// MARK: – Single cell
struct Tile: View {
    let tileItem: TileItem
    let size: CGSize
    
    var body: some View {
        return VStack(spacing: 0) {
            switch(tileItem.imageSource) {
            case .local(let imageName):
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 12)
            case .remote(let imageUrl):
                AsyncImage(url: imageUrl) { phase in
                    ZStack {
                        switch phase {
                        case .empty:
                            ProgressView()
                            
                        case .success(let image):
                            image
                             .resizable()
                             .scaledToFit()
                            
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(height:75)
                                .foregroundColor(.gray)
                            
                        @unknown default:
                            EmptyView()
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            }
                        
            Rectangle()
                .fill(.white)
                .frame(height: 2)
                .padding(.horizontal, 12)
            
            TwoLineText(content: tileItem.title, color: tileItem.textColor)
        }
        .frame(width: size.width, height: size.height)
        .background(tileItem.color)
        .cornerRadius(12)
    }
}

struct TwoLineText: View {
    let content: String
    let color: Color
    
    var body: some View {
        Text("\n").font(.system(size: 30, weight: .regular))
            .frame(maxWidth: .infinity)
            .padding(12)
            .overlay(
                Text(content).font(.system(size: 30, weight: .regular))
                    .foregroundColor(color)
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
        let leftItem = TestTile(tileItem: TileItem(title: "Left Tile", imageSource: ImageSource.local("info"), color: Color("calliope-pink"), textColor: .white))
        let rightItems = [
            TestTile(tileItem: TileItem(title: "Right Tile 1",    imageSource: ImageSource.local("facerobot"), color: Color("calliope-lilablau"), textColor: .white)),
            TestTile(tileItem: TileItem(title: "Right Tile 2",    imageSource: ImageSource.local("speak"), color: Color("calliope-orange"), textColor: .white)),
            TestTile(tileItem: TileItem(title: "Right Tile 3",    imageSource: ImageSource.local("control"), color: Color("calliope-turqoise"), textColor: .white)),
            TestTile(tileItem: TileItem(title: "Right Tile 4",    imageSource: ImageSource.local("teachablemachine"), color: Color("calliope-darkgreen"), textColor: .white))
        ]
        let callback: (TestTile) -> Void =  { testTile in
            LogNotify.log("Clicked on \(testTile.tileItem.title)")
        }
        let tileData = TileData<TestTile>(rightItems: rightItems)
        TilePageLayout(leftItem: leftItem, data: tileData, leftItemOnTap: callback, rightItemsOnTap: callback)
        
    }
}


