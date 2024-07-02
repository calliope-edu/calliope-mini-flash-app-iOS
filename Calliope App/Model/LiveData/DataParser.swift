//
//  DataParser.swift
//  Calliope App
//
//  Created by itestra on 02.07.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

class DataParser {
    
    static func encode(data: Any, service: CalliopeService) -> String {
        switch service {
        case .accelerometer, .magnetometer:
            let value = data as! (Double, Double, Double)
            let array = [value.0, value.1, value.2]
            if let jsonData = try? JSONEncoder().encode(array), let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return ""
        default:
            let value = data as! Double
            if let jsonData = try? JSONEncoder().encode(value), let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return ""
        }
    }
    
    static func decode(data: String, service: CalliopeService) -> Any {
        switch service {
        case .accelerometer:
            if let jsonData = data.data(using: .utf8), let array = try? JSONDecoder().decode([Double].self, from: jsonData), array.count == 3 {
                return (array[0], array[1], array[2])
            }
            return (0, 0, 0)
        default:
            if let jsonData = data.data(using: .utf8), let value = try? JSONDecoder().decode(Double.self, from: jsonData) {
                return value
            }
            return 0
        }
    }
    
}
