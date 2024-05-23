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
                dbQueue = try DatabaseQueue(path: dbPath)
                
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
                try SensorRecording.createTable(in: db)
                try Value.createTable(in: db)
            }
        } catch {
            LogNotify.log("Creating tables failed, they might already exist.")
        }
        
    }

    func insertProject(name: String, values: String) -> Project? {
        var tempProject: Project? = nil
        do {
            try DatabaseManager.shared.dbQueue?.write { db in
                var project = Project(name: name, values: values)
                try project.insert(db)
                tempProject = project
            }
        } catch {
            print("Failed to insert project: \(error)")
        }
        notifyChange()
        return tempProject
    }
    
    func fetchProjects() -> [Project] {
        var retrievedProjects: [Project] = []
        do {
            try DatabaseManager.shared.dbQueue?.read { db in
                retrievedProjects = try Project.fetchAll(db)
            }
        } catch {
            LogNotify.log("Error fetching project data from database: \(error)")
        }
        return retrievedProjects
    }
    
    func fetchProject(id: Int) -> Project? {
        var retrievedProjects: Project?
        do {
            try DatabaseManager.shared.dbQueue?.read { db in
                retrievedProjects = try Project.fetchOne(db, key: id)
            }
        } catch {
            LogNotify.log("Error fetching project data from database: \(error)")
        }
        return retrievedProjects
    }
    
    func notifyChange() {
        NotificationCenter.default.post(name: NotificationConstants.hexFileChanged, object: self)
    }
}

