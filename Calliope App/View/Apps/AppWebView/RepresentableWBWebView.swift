//
//  RepresentableWBWebView.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit

struct RepresentableWBWebView: UIViewRepresentable {
    let url: URL
    let bridge: WebAppBridge
    let alertPublisher: Alertable
    let connection: DeviceConnectionService
    let connectionPanel: ConnectionPanel
    let onDownload: (_ filename: String, _ contents: Data) -> Void

    func makeUIView(context: Context) -> WBWebViewContainer {
        WBWebViewContainer(bridge: bridge, alertPublisher: alertPublisher, connection: connection, connectionPanel: connectionPanel, onDownload: onDownload)
    }

    func updateUIView(_ container: WBWebViewContainer, context: Context) {
        container.load(url: url)
    }

    static func dismantleUIView(_ container: WBWebViewContainer, coordinator: ()) {
        container.removeHandlers()
    }
}
