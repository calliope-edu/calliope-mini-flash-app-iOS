//
//  SensorRecording.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import GRDB

struct SensorRecording: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var projectId: Int64
    var sensorType: String

    enum Columns: String, ColumnExpression {
        case id, projectId, sensorType, values
    }

    static let databaseTableName = "sensorRecordings"
}

extension SensorRecording {
    // Define the table structure
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("projectId", .text).notNull()
            t.column("sensorType", .text).notNull()
        }
        LogNotify.log("sensor recording table created")
    }
}
