//
//  SensordataPageController.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class SensordataPageController: UIViewController {
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: SensordataView(viewModel: SensordataViewModel()))
    }
    @IBSegueAction func addSwiftUI2(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: SensordataView(viewModel: SensordataViewModel()))
    }
    
}
