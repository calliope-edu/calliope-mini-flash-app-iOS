//
//  LofiAppsPage.swift
//  Calliope App
//
//  Created by Calliope on 20.02.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct AdaptiveStack<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        GeometryReader { geo in
            // Decide orientation from the *available* size
            if geo.size.width > geo.size.height {
                HStack(content: content)          // landscape
            } else {
                VStack(content: content)          // portrait
            }
        }
        // GeometryReader expands to fill its parent, so we collapse it:
        .ignoresSafeArea(edges: .all)   // optional – remove if you need safe‑area padding
    }
}

struct LofiAppsPage : View {
    var body: some View {
        AdaptiveStack {
            AppCell(app: AppItem(title: "Maps", imageName: "calliope_datalogger_extension", color: Color("calliope-pink")))
            ContentView()
       }
        .padding()
    }
}


// MARK: – Model
struct AppItem: Identifiable {
    let id = UUID()
    let title: String
    let imageName: String // name of an asset in the catalog
    let color: Color
}

// MARK: – Grid view
struct AppsGridView: View {
    // data source
    let apps: [AppItem]

    // called when a cell is tapped
    var onSelect: (AppItem) -> Void

    // two‑column grid; adjust `columns` to any layout you like
    private let columns = [
        GridItem(.flexible(), spacing: 0),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(apps) { app in
                    AppCell(app: app)
                        .onTapGesture { onSelect(app) }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: – Single cell
struct AppCell: View {
    let app: AppItem
    
    var body: some View {
        VStack(spacing: 0) {                 // we’ll control spacing ourselves
            // ---- Image ----
            Image(app.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 250)          // choose any height you like
                .padding(.vertical, 8)            // space above the image
            
            // ---- Divider (white thin line) ----
            Rectangle()
                .fill(.white)
                .frame(height: 2)
                .padding(.horizontal, 12)   // inset a little from the sides
            
            // ---- Title ----
            Text(app.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.vertical, 8)       // space below the text
        }
        .frame(maxWidth: .infinity)         // fill the column width
        .background(app.color)    // cell background (light gray)
        .cornerRadius(12)
        .padding(.vertical, 8)               // **extra space between cells**
    }
}

// MARK: – Example usage
struct ContentView: View {
    // sample data
    let sampleApps = [
        AppItem(title: "ROBOTER MIT GESICHTSERKENNUNG STEUERN",    imageName: "calliope_datalogger_extension", color: Color("calliope-lilablau")),
        AppItem(title: "SPRACHROBOTER",  imageName: "calliope_datalogger_extension", color: Color("calliope-orange")),
        AppItem(title: "STEUERUNG PER COMPUTER",    imageName: "calliope_datalogger_extension", color: Color("calliope-turqoise")),
        AppItem(title: "OBJEKTERKENNUNG MIT KÜNSTLICHER INTELLIGENZ",   imageName: "calliope_datalogger_extension", color: Color("calliope-darkgreen")),
    ]

    var body: some View {
        AppsGridView(apps: sampleApps) { selectedApp in
            // ← this is the function that runs when a cell is tapped
            print("🚀 Selected app: \(selectedApp.title)")
            // you can push a new view, open a URL, etc.
        }
    }}

// MARK: – Preview
struct LofiAppsPage_Previews: PreviewProvider {
    static var previews: some View {
        LofiAppsPage()
    }
}
