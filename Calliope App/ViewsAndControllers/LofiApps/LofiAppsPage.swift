//
//  LofiAppsPage.swift
//  Calliope App
//
//  Created by Calliope on 20.02.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

enum Orientation {
    case landscape
    case portrait
}

struct LofiAppsPage : View {
    let parentViewController: LofiAppsViewController?
    
    let apps = [
        AppItem(title: "ROBOTER MIT GESICHTSERKENNUNG STEUERN",    imageName: "facerobot", color: Color("calliope-lilablau"), url: "https://go.calliope.cc/facerobot?mobile=true"),
        AppItem(title: "SPRACHROBOTER",  imageName: "speak", color: Color("calliope-orange"), url: "https://cardboard.lofirobot.com/apps/talking-robots"),
        AppItem(title: "STEUERUNG PER COMPUTER",    imageName: "control", color: Color("calliope-turqoise"), url: "https://go.calliope.cc/apps/control/index.html?mobile=true"),
        AppItem(title: "OBJEKTERKENNUNG MIT KÜNSTLICHER INTELLIGENZ",   imageName: "teachablemachine", color: Color("calliope-darkgreen"), url: "https://go.calliope.cc/teachablemachine/index.html?mobile=true"),
    ]
    
    let infoAppItem = AppItem(title: "INFO", imageName: "info", color: Color("calliope-pink"), url: "https://calliope.cc/programmieren/mobil/ble-anwendungen")
    
    @State private var orientation: Orientation = Orientation.landscape
    @State private var cellSize: CGSize = CGSize(width: 0, height: 0)
    
    
    var body: some View {
        GeometryReader(content: self.updateGeometry).padding()
        
    }
    
    func updateGeometry(geometry: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            orientation = calculateOrientation(pageSize: geometry.size)
            cellSize = calculateCellSize(pageSize: geometry.size, orientation: orientation)
        }
        
        if orientation == .landscape {
            return AnyView(HStack(spacing: 16) {
                getStackContent(orientation: orientation, cellSize: cellSize)
            })
        } else {
            return AnyView(VStack(spacing: 16) {
                getStackContent(orientation: orientation, cellSize: cellSize)
            })
        }
    }

    func getStackContent(orientation: Orientation, cellSize: CGSize) -> some View {
        Group {
            AppCell(app: infoAppItem, size: cellSize).onTapGesture {
                self.selectInfo(url: infoAppItem.url)
            }
            AppsGridView(cellSize: cellSize, orientation: orientation, apps: apps) { selectedApp in
                self.selectLofiApp(app: selectedApp)
            }
        }
    }

    
    func calculateOrientation(pageSize: CGSize) -> Orientation {
        return pageSize.width > pageSize.height ? Orientation.landscape : Orientation.portrait
    }
    
    func calculateCellSize(pageSize: CGSize, orientation: Orientation) -> CGSize {
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
    
    func selectLofiApp(app: AppItem) {
        guard parentViewController != nil else {
            LogNotify.log("HostingViewController is nil. This should not happen.", level: LogNotify.LEVEL.ERROR)
            return
        }
        parentViewController!.setSelectedApp(app: app)
        parentViewController!.performSegue(withIdentifier: "showLofiWebView", sender: self)
    }
    
    func selectInfo(url: String) {
        guard parentViewController != nil else {
            LogNotify.log("HostingViewController is nil. This should not happen.", level: LogNotify.LEVEL.ERROR)
            return
        }
        parentViewController!.selectedInfo(url: url)
        parentViewController!.performSegue(withIdentifier: "showInfo", sender: self)
    }
}


// MARK: – Grid view
struct AppsGridView: View {
    @State private var widthRatio: CGFloat = 1.2
    
    let cellSize: CGSize
    
    let orientation: Orientation
    
    // data source
    let apps: [AppItem]

    // called when a cell is tapped
    var onSelect: (AppItem) -> Void

    // two‑column grid; adjust `columns` to any layout you like
    private let columns = [
        GridItem(.flexible(), spacing: 0),
    ]

    var body: some View {
        ScrollView(orientation == Orientation.landscape ? Axis.Set.vertical : Axis.Set.horizontal) {
            if orientation == Orientation.portrait {
                LazyHGrid(rows: columns, spacing: 8) {
                    ForEach(apps) { app in
                        AppCell(app: app, size: cellSize)
                            .onTapGesture { onSelect(app) }
                    }
                }
                .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(apps) { app in
                        AppCell(app: app, size: cellSize)
                            .onTapGesture { onSelect(app) }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: – Model
struct AppItem: Identifiable {
    let id = UUID()
    let title: String
    let imageName: String // name of an asset in the catalog
    let color: Color
    let url: String
}


// MARK: – Single cell
struct AppCell: View {
    let app: AppItem
    let size: CGSize
    
    var body: some View {
        VStack(spacing: 0) {                 // we’ll control spacing ourselves
            // ---- Image ----
            Image(app.imageName)
                .resizable()
                .scaledToFit()
                .padding(.vertical, 12)            // space above the image
            
            // ---- Divider (white thin line) ----
            Rectangle()
                .fill(.white)
                .frame(height: 2)
                .padding(.horizontal, 12)   // inset a little from the sides
            
            // ---- Title ----
            TwoLineText(content: app.title)
        }
        .frame(width: size.width, height: size.height)
        .background(app.color)    // cell background (light gray)
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
struct LofiAppsPage_Previews: PreviewProvider {
    static var previews: some View {
        LofiAppsPage(parentViewController: nil)
    }
}


