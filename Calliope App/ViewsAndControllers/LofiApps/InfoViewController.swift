//
//  InfoViewController.swift
//  Calliope App
//
//  Created by Calliope on 27.02.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

class InfoViewController: UIViewController {
    public var url: URL!
    
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: WebView(url: url))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Apps Info"
    }
}
