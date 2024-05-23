//
//  Project.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import GRDB
import DeepDiff

struct Project: Codable, FetchableRecord, PersistableRecord, DiffAware {
    typealias DiffId = String
    var diffId: DiffId { return name }
    
    static func compareContent(_ a: Project, _ b: Project) -> Bool {
        a.name == b.name && a.values == b.values
    }
    
    var id: Int64?
    var name: String
    var values: String
    
    static let databaseTableName = "projects"
}

extension Project {
    // Define the table structure
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("values", .text).notNull()
        }
        LogNotify.log("project table created")
    }
}
