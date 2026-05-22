//
//  Project.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import GRDB
import DeepDiff

struct Group: Codable, FetchableRecord, PersistableRecord, DiffAware {

    static let databaseTableName = "groups"

    var id: Int64?
    var projectsId: Int64?

    typealias DiffId = String
    var diffId: DiffId {
        return ""
    }

    static func compareContent(_ a: Group, _ b: Group) -> Bool {
        a.id == b.id && a.projectsId == b.projectsId
    }

    static func insertGroup(projectsId: Int64) -> Group? {
        
        var tempGroup: Group? = nil
        do {
            try DatabaseManager.shared.databaseQueue?.write { db in
                let group = Group(projectsId: projectsId)
                try group.insert(db)
                tempGroup = group
                tempGroup?.id = db.lastInsertedRowID
            }
        } catch {
            LogNotify.log("Failed to insert group: \(error)")
        }
        DatabaseManager.notifyChange()
        return tempGroup
    }

    static func fetchGroups() -> [Group] {
        var retrievedGroups: [Group] = []
        do {
            try DatabaseManager.shared.databaseQueue?.read { db in
                retrievedGroups = try Group.fetchAll(db)
            }
        } catch {
            LogNotify.log("Error fetching groups from database: \(error)")
        }
        return retrievedGroups
    }

    static func fetchGroup(projectId: Int) -> Group? {
        var retrievedGroups: Group?
        do {
            try DatabaseManager.shared.databaseQueue?.read { db in
                retrievedGroups = try Group.fetchOne(db, key: projectId)
            }
        } catch {
            LogNotify.log("Error fetching group from database: \(error)")
        }
        return retrievedGroups
    }
}

extension Group {
    // Define the table structure
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("projectsId", .double).notNull()
            t.foreignKey(["projectsId"], references: "projects", onDelete: .cascade)
        }
        LogNotify.log("group table created")
    }
}
