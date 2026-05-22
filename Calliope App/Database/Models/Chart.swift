//
//  Chart.swift
//  Calliope App
//
//  Created by itestra on 07.06.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import GRDB
import DeepDiff

struct Chart: Codable, FetchableRecord, PersistableRecord, DiffAware, Identifiable {

    static let databaseTableName = "charts"

    var id: Int64?
    var sensorType: CalliopeService?
    var groupsId: Int64?

    typealias DiffId = String
    var diffId: DiffId {
        return ""
    }

    static func compareContent(_ a: Chart, _ b: Chart) -> Bool {
        a.sensorType == b.sensorType && a.id == b.id
    }

    static func insertChart(sensorType: CalliopeService?, groupsId: Int64?) -> Chart? {
        var tmpChart: Chart? = nil
        do {
            try DatabaseManager.shared.databaseQueue?.write { db in
                let chart = Chart(sensorType: sensorType, groupsId: groupsId)
                tmpChart = try chart.inserted(db)
                tmpChart?.id = db.lastInsertedRowID
            }
        } catch {
            LogNotify.log("Failed to insert project: \(error)")
        }
        DatabaseManager.notifyChange()
        return tmpChart
    }
    
    static func setSensorType(chart: Chart) {
        guard chart.sensorType != nil else {
            LogNotify.log("Tried to set sensor type, but no sensor type given.", level: LogNotify.LEVEL.ERROR)
            return
        }
        do {
            try DatabaseManager.shared.databaseQueue?.write { db in
                try chart.update(db)
            }
        } catch {
            LogNotify.log("Error setting the sensor type of chart: \(error)")
        }
    }

    static func fetchChartsBy(groupsId: Int64?) -> [Chart] {
        var retrievedCharts: [Chart] = []
        do {
            try DatabaseManager.shared.databaseQueue?.read { db in
                retrievedCharts = try Chart.fetchAll(db)
                retrievedCharts = retrievedCharts.filter({ chart in
                    return chart.groupsId == groupsId
                })
            }
        } catch {
            LogNotify.log("Error fetching charts data from database: \(error)")
            return retrievedCharts
        }
        return retrievedCharts
    }

    static func deleteChart(id: Int64?) {
        do {
            try DatabaseManager.shared.databaseQueue?.write { db in
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
            t.column("sensorType", .any)
            t.column("groupsId", .double).notNull()
            t.foreignKey(["groupsId"], references: "groups", onDelete: .cascade)
        }
        LogNotify.log("project table created")
    }
}

