//
//  DatabaseManager.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import SQLite3

import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()
    var databaseQueue: DatabaseQueue?

    private init() {
        do {
            let fileManager = FileManager.default
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dbPath = documentDirectory.appendingPathComponent("CalliopeDatabase.sqlite").path
            var config = Configuration()

            config.readonly = false
            databaseQueue = try DatabaseQueue(path: dbPath, configuration: config)

            guard let databaseQueue else {
                LogNotify.log("DatabaseQueue is nil, which should not happen at this point.")
                return
            }

            var migrator = DatabaseMigrator()

            #if DEBUG
            migrator.eraseDatabaseOnSchemaChange = true
            #endif

            try createTables(databaseQueue)
            try migrator.migrate(databaseQueue)
        } catch {
            LogNotify.log("Database setup failed: \(error)")
        }
    }

    func createTables(_ dbQueue: DatabaseQueue) throws {
        let tableExist = try dbQueue.read { db in
            (project: try db.tableExists(Project.databaseTableName), chart: try db.tableExists(Chart.databaseTableName), value: try db.tableExists(Value.databaseTableName))
        }

        if tableExist.project && tableExist.chart && tableExist.value {
            return
        }

        try dbQueue.write {
            db in
            // Create a table for users as an example
            if !tableExist.project {
                try Project.createTable(in: db)
            }

            if !tableExist.chart {
                try Chart.createTable(in: db)
            }

            if !tableExist.value {
                try Value.createTable(in: db)
            }
        }

    }

    static func notifyChange() {
        NotificationCenter.default.post(name: NotificationConstants.projectsChanged, object: self)
    }
}

