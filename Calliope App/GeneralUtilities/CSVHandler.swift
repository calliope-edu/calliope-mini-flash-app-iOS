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
            print("Error getting documents directory URL")
            return
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(fileName).csv")
        
        // Write the string to the file
        do {
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
            print("File saved: \(fileURL)")
        } catch {
            print("Error writing to file: \(error)")
        }
    }
    
    static func convertToCSVString(project: Int64?) -> String {
        guard let project else {
            fatalError()
        }
        var csvString = ""
        
        // Get the headers from the keys of the first dictionary
        let headers = "timestep, value \n "
        csvString += headers
        
        let data = fetchDataFor(project: project)
        
        // Add the rows
        for row in data {
            var rowString = ""
            for value in row {
                rowString += "\(value)"
                rowString += ","
            }
            csvString += rowString + "\n"
        }
        
        return csvString
    }

    
    static func fetchDataFor(project: Int64) -> [[String]]{
        let charts = Chart.fetchChartsBy(projectsId: project)
        var dataValues: [[String]] = []
        for chart in charts! {
            //TODO: Handle Axis Properly
            let values = Value.fetchValuesBy(chartId: chart.id)
            for value in values {
                var entry: [String] = []
                dataValues.append(entry)
            }
            
        }
        return dataValues
    }
    
}
