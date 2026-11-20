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
    let alertPublisher: Alertable
    let connection: DeviceConnectionService
    let connectionPanel: ConnectionPanel

    func makeUIView(context: Context) -> WBWebViewContainer {
        WBWebViewContainer(alertPublisher: alertPublisher, connection: connection, connectionPanel: connectionPanel)
    }

    func updateUIView(_ container: WBWebViewContainer, context: Context) {
        container.load(url: url)
    }

    static func dismantleUIView(_ container: WBWebViewContainer, coordinator: ()) {
        container.removeHandlers()
    }
}
