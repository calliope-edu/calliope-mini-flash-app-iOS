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
            // Define the path to the database file
            let fileManager = FileManager.default
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dbPath = documentDirectory.appendingPathComponent("CalliopeDatabase.sqlite").path
            
            // Create the database queue
            var config = Configuration()
            config.readonly = false
            dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
            
            // Perform the initial setup (e.g., creating tables)
            createTables()
        } catch {
            print("Database setup failed: \(error)")
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
    
    static func notifyChange() {
        NotificationCenter.default.post(name: NotificationConstants.projectsChanged, object: self)
    }
}

