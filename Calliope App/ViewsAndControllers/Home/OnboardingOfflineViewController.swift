//
//  OnboardingOfflineViewController.swift
//  Calliope App
//
//  Created by itestra on 05.12.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import SwiftUI

class OnboardingOfflineViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: OfflineOnboardingView())
    }
}
