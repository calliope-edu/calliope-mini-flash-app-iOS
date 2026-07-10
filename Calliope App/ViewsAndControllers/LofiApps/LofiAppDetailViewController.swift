//
//  LofiAppViewController.swift
//  Calliope App
//
//  Created by Calliope on 16.01.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class LofiAppDetailViewController: UIViewController {
    
    public var url: URL!
    public var appTitle: String!
    
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: RepresentableWBWebView(url: url))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = appTitle
    }
}
