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

    static let databaseTableName = "projects"

    var id: Int64?
    var name: String

    typealias DiffId = String
    var diffId: DiffId {
        return name
    }

    static func compareContent(_ a: Project, _ b: Project) -> Bool {
        a.name == b.name
    }

    static func insertProject(name: String) -> Project? {
        var tempProject: Project? = nil
        do {
            try DatabaseManager.shared.databaseQueue?.write { db in
                let project = Project(name: name)
                try project.insert(db)
                tempProject = project
                tempProject?.id = db.lastInsertedRowID
            }
        } catch {
            LogNotify.log("Failed to insert project: \(error)")
        }
        DatabaseManager.notifyChange()
        return tempProject
    }

    static func fetchProjects() -> [Project] {
        var retrievedProjects: [Project] = []
        do {
            try DatabaseManager.shared.databaseQueue?.read { db in
                retrievedProjects = try Project.fetchAll(db)
            }
        } catch {
            LogNotify.log("Error fetching project data from database: \(error)")
        }
        return retrievedProjects
    }

    static func fetchProject(id: Int) -> Project? {
        var retrievedProjects: Project?
        do {
            try DatabaseManager.shared.databaseQueue?.read { db in
                retrievedProjects = try Project.fetchOne(db, key: id)
            }
        } catch {
            LogNotify.log("Error fetching project data from database: \(error)")
        }
        return retrievedProjects
    }

    static func deleteProject(id: Int64?) {
        do {
            try DatabaseManager.shared.databaseQueue?.write { db in
                try Project.deleteOne(db, key: id)
                LogNotify.log("Deleted project with id \(String(describing: id ?? nil))")
            }
        } catch {
            LogNotify.log("Error deleting project: \(error)")
        }
    }

    static func updateProject(project: Project) {
        do {
            try DatabaseManager.shared.databaseQueue?.write { db in
                try project.update(db)
            }
        } catch {
            LogNotify.log("Error updating project: \(error)")
        }
    }
}

extension Project {
    // Define the table structure
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
        }
        LogNotify.log("project table created")
    }
}
