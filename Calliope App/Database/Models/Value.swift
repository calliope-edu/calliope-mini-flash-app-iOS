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
    
    static let databaseTableName = "value"
    
    var id: Int64?
    var value: String
    var time: Double
    var chartsId: Int64
    
    static func insertValue(value: String, chartsId: Int64) {
        do {
            try DatabaseManager.shared.dbQueue?.write { db in
                try Value(value: value, time: (Date().timeIntervalSinceReferenceDate * 100).rounded(toPlaces: 0), chartsId: chartsId).insert(db)
            }
        } catch {
            LogNotify.log("Failed to insert value: \(error)")
        }
        DatabaseManager.notifyChange()
    }
    
    static func fetchValuesBy(chartId: Int64?) -> [Value] {
        var retrievedValues: [Value] = []
        do {
            try DatabaseManager.shared.dbQueue?.read { db in
                retrievedValues = try Value.fetchAll(db).filter({ value in
                    return value.chartsId == chartId
                })
            }
        } catch {
            LogNotify.log("Error fetching values from database: \(error)")
        }
        return retrievedValues
    }
}

extension Value {
    // Define the table structure
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("value", .text).notNull()
            t.column("time", .text).notNull()
            t.column("chartsId", .text).notNull()
            t.foreignKey(["chartsId"], references: "charts", onDelete: .cascade)
        }
        LogNotify.log("value table created")
    }
    
}
