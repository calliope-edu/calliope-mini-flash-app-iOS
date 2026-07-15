//
//  NewsDetailWebViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 30.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit
import WebKit
import SwiftUI

class NewsDetailWebViewController: UIViewController, WKNavigationDelegate {

    public var url: URL!

    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: WebView(url: url, navigationDelegate: self))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let navigationController = self.navigationController {
            var stack = navigationController.viewControllers

            stack.removeLast()

            let fallbackVC = storyboard!.instantiateViewController(withIdentifier: "onboardingOffline")
            stack.append(fallbackVC)

            navigationController.setViewControllers(stack, animated: true)
        }
    }
}
