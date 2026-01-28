//
//  Double+Extension.swift
//  Calliope App
//
//  Created by Calliope on 06.05.25.
//  Copyright © 2025 calliope. All rights reserved.
//
import Foundation

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
