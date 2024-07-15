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
    var dbQueue: DatabaseQueue?

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dbPath = documentDirectory.appendingPathComponent("CalliopeDatabase.sqlite").path
            var config = Configuration()
            
            config.readonly = false
            dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
            
            var migrator = DatabaseMigrator()
            registerMigrations(migrator: migrator)
            
            #if DEBUG
            migrator.eraseDatabaseOnSchemaChange = true
            #endif
            
            createTables()
            try migrator.migrate(dbQueue!)
        } catch {
            LogNotify.log("Database setup failed: \(error)")
        }
    }

    func createTables() {
        do {
            try dbQueue?.write { db in
                // Create a table for users as an example
                try Project.createTable(in: db)
                try Chart.createTable(in: db)
                try Value.createTable(in: db)
            }
        } catch {
            LogNotify.log("Creating tables failed, they might already exist. \(error)")
        }
    }
    
    private func registerMigrations(migrator: DatabaseMigrator) {
        LogNotify.log("Performing Migrations")
    }
    
    static func notifyChange() {
        NotificationCenter.default.post(name: NotificationConstants.projectsChanged, object: self)
    }
}

