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

struct RepresentableWBWebView: UIViewControllerRepresentable {
    @State var url: URL
    let alertPublisher: Alertable
    let connection: DeviceConnectionService
    let connectionPanel: ConnectionPanel

    private var wBWebViewContainerController: WBWebViewContainerController?

    init(url: URL, alertPublisher: Alertable, connection: DeviceConnectionService, connectionPanel: ConnectionPanel) {
        self.url = url
        self.alertPublisher = alertPublisher
        self.connection = connection
        self.connectionPanel = connectionPanel
    }

    func makeUIViewController(context: Context) -> WBWebViewContainerController {
        let storyboard = UIStoryboard(name: "WBCore", bundle: .main)

        let controller = storyboard.instantiateInitialViewController() as! WBWebViewContainerController
        controller.alertPublisher = alertPublisher
        controller.connection = connection
        controller.connectionPanel = connectionPanel
        return controller
    }

    func updateUIViewController(_ controller: WBWebViewContainerController, context: Context) {
        if controller.isViewLoaded {
            controller.enableNativeBridgeIfNeeded(for: url)
            controller.webView.load(URLRequest(url: url))
        }
    }
}
