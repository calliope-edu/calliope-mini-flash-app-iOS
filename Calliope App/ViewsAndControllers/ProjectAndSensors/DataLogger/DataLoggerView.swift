//
//  DataLoggerView.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct DataLoggerView: View {
    let html: String

    var body: some View {
        WebView(html: html)
    }
}
