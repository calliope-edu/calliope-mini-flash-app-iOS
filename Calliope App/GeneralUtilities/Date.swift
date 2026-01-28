//
//  Date.swift
//  Calliope App
//
//  Created by Calliope on 05.05.25.
//  Copyright © 2025 calliope. All rights reserved.
//

import Foundation

extension Date {
    func getFormattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return dateFormatter.string(from: self)
    }
}
