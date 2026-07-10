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

    private var wBWebViewContainerController: WBWebViewContainerController?

    init(url: URL) {
        self.url = url
    }

    func makeUIViewController(context: Context) -> WBWebViewContainerController {
        let storyboard = UIStoryboard(name: "WBCore", bundle: .main)

        let controller = storyboard.instantiateInitialViewController() as! WBWebViewContainerController
        return controller
    }

    func updateUIViewController(_ controller: WBWebViewContainerController, context: Context) {
        if controller.isViewLoaded {
            controller.webView.load(URLRequest(url: url))
        }
    }
}
