//
//  CSVHandler.swift
//  Calliope App
//
//  Created by itestra on 28.06.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

class CSVHandler {
    
    static func exportToCSVFile(contents: String, fileName: String) {
        let fileManager = FileManager.default
        
        // Get the documents directory URL
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            LogNotify.log("Error getting documents directory URL")
            return
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(fileName).csv")
        
        // Write the string to the file
        do {
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
            LogNotify.log("File saved: \(fileURL)")
        } catch {
            LogNotify.log("Error writing to file: \(error)")
        }
    }
    
    static func convertToCSVString(project: Int64?) -> String {
        guard let project else {
            fatalError()
        }
        var csvString = "timestep, value, axisName, sensor_type, latitude, longitude \n"
        for row in fetchDataFor(project: project) {
            csvString += "\(row.0), \(row.1), \(row.2), \(row.3), \(row.4.map { String($0) } ?? ""), \(row.5.map { String($0) } ?? "")\n"
        }
        return csvString
    }

    
    static func fetchDataFor(project: Int64) -> [(Double, Double, String, CalliopeService, Double?, Double?)]{
        var dataValues: [(Double, Double, String, CalliopeService, Double?, Double?)] = []
        for chart in Chart.fetchChartsBy(projectsId: project) {
            for value in Value.fetchValuesBy(chartId: chart.id) {
                for entry in DataParser.decode(data: value.value, service: chart.sensorType ?? .empty) {
                    dataValues.append((value.time, entry.value, entry.key, chart.sensorType ?? .empty, value.lat, value.long))
                }
            }
        }
        return dataValues
    }
    
}
