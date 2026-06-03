//
//  DataLoggerViewModel.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

class DataLoggerViewModel: UIViewController {
    
    private var html: String?
    var htmlData: Data {
        get {
            html?.data(using: .utf8) ?? Data()
        }
        set {
            html = String(decoding: newValue, as: UTF8.self)
        }
    }
    
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        guard html != nil else {
            LogNotify.error("html is nil. This should not happen.")
            return nil
        }
        return UIHostingController(coder: coder, rootView: DataLoggerView(html: html!))
    }
}
