//
//  Chart.swift
//  Calliope App
//
//  Created by itestra on 07.06.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import GRDB
import DeepDiff

struct Chart: Codable, FetchableRecord, PersistableRecord, DiffAware {
    typealias DiffId = String
    var diffId: DiffId { return "" }
    
    static func compareContent(_ a: Chart, _ b: Chart) -> Bool {
        a.sensorType == b.sensorType && a.id == b.id
    }
    
    var id: Int64?
    var sensorType: CalliopeService
    var projectsId: Int64?
    
    static let databaseTableName = "charts"
    
    static func insertChart(sensorType: CalliopeService, projectsId: Int64?) -> Chart? {
        var tmpChart: Chart? = nil
        do {
            try DatabaseManager.shared.dbQueue?.write { db in
                var chart = Chart(sensorType: sensorType, projectsId: projectsId)
                tmpChart = try chart.inserted(db)
                tmpChart?.id = db.lastInsertedRowID
            }
        } catch {
            print("Failed to insert project: \(error)")
        }
        DatabaseManager.notifyChange()
        return tmpChart
    }
    
    static func fetchChartsBy(projectsId: Int64?) -> [Chart]? {
        var retrievedCharts: [Chart]?
        do {
            try DatabaseManager.shared.dbQueue?.read { db in
                retrievedCharts = try Chart.fetchAll(db)
                retrievedCharts = retrievedCharts?.filter({ chart in
                    return chart.projectsId == projectsId
                })
            }
        } catch {
            LogNotify.log("Error fetching charts data from database: \(error)")
        }
        return retrievedCharts
    }
    
    static func deleteChart(id: Int64?) {
        do {
            try DatabaseManager.shared.dbQueue?.write { db in
                try Chart.deleteOne(db, key: id)
                LogNotify.log("Deleted chart with id \(id ?? nil ?? 0)")
            }
        } catch {
            LogNotify.log("Error deleting chart: \(error)")
        }
    }
}

extension Chart {
    // Define the table structure
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("sensorType", .any).notNull()
            t.column("projectsId", .double).notNull()
            t.foreignKey(["projectsId"], references: "projects", onDelete: .cascade)
        }
        LogNotify.log("project table created")
    }
}

