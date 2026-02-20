//
//  LofiAppsViewController.swift
//  Calliope App
//
//  Created by OpenAI Assistant on 2026-02-20.
//

import UIKit
import SwiftUI

/// A blank view controller displayed under the new "LofiApps" tab.
final class LofiAppsViewController: UIViewController {

    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: SwiftUIView())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
