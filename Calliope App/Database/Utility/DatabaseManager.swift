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

            try migration(databaseQueue);

        } catch {
            LogNotify.log("Database setup failed: \(error)")
        }
    }


    func migration(_ databaseQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // initial version of sensor data view
        try createTables(databaseQueue)

        // migration of key to correct types
        migrator.registerMigration("Change FK column types to integer") { db in
            try db.create(table: "charts_migration") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sensorType", .any)
                t.column("projectsId", .integer).notNull()
                t.foreignKey(["projectsId"], references: "projects", onDelete: .cascade)
            }

            let chartRows = try Row.fetchCursor(db, sql: "SELECT * FROM charts")
            while let row = try chartRows.next() {
                try db.execute(
                    sql: "INSERT INTO charts_migration (id, sensorType, projects) VALUES (?, ?, ?)",
                    arguments: [
                      row["id"],
                      row["sensorType"],
                      row["projectsId"] as Int64
                      ])
            }

            try db.drop(table: "charts")
            try db.rename(table: "charts_migration", to: "charts")

        try db.create(table: "value_migration") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("value", .text).notNull()
            t.column("time", .text).notNull()
            t.column("chartsId", .integer).notNull()
            t.foreignKey(["chartsId"], references: "charts", onDelete: .cascade)
        }

            let valueRows = try Row.fetchCursor(db, sql: "SELECT * FROM value")
            while let row = try valueRows.next() {
                try db.execute(
                    sql: "INSERT INTO value_migration (id, value, time, chartsId) VALUES (?, ?, ?, ?)",
                    arguments: [
                      row["id"],
                      row["value"],
                      row["time"],
                      row["chartsId"] as Int64
                      ])
            }

            try db.drop(table: "value")
            try db.rename(table: "value_migration", to: "value")
        }


        try migrator.migrate(databaseQueue)
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

