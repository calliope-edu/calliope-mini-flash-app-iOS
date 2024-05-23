//
//  Value.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import GRDB

struct Value: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var recordingId: Int64
    var value: Double
    
    static let databaseTableName = "value"
}

extension Value {
    // Define the table structure
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("recordingId", .text).notNull()
            t.column("value", .text).notNull()
        }
        LogNotify.log("value table created")
    }
    
}
