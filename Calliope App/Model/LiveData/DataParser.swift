//
//  DataParser.swift
//  Calliope App
//
//  Created by itestra on 02.07.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

class DataParser {
    
    static func encode(data: [String: Double], service: CalliopeService) -> String {
        if let jsonData = try? JSONEncoder().encode(data), let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return ""
    }
    
    static func decode(data: String, service: CalliopeService) -> [String: Double] {
        if let jsonData = data.data(using: .utf8), let decoded = try? JSONDecoder().decode([String: Double].self, from: jsonData) {
            return decoded
        }
        return ["0": 0]
    }
    
}
