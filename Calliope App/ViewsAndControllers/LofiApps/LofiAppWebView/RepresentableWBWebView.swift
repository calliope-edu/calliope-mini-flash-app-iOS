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

    private var wBWebViewContainerController: WBWebViewContainerController?

    init(url: URL, alertPublisher: Alertable) {
        self.url = url
        self.alertPublisher = alertPublisher
    }

    func makeUIViewController(context: Context) -> WBWebViewContainerController {
        let storyboard = UIStoryboard(name: "WBCore", bundle: .main)

        let controller = storyboard.instantiateInitialViewController() as! WBWebViewContainerController
        controller.alertPublisher = alertPublisher
        return controller
    }

    func updateUIViewController(_ controller: WBWebViewContainerController, context: Context) {
        if controller.isViewLoaded {
            controller.webView.load(URLRequest(url: url))
        }
    }
}
