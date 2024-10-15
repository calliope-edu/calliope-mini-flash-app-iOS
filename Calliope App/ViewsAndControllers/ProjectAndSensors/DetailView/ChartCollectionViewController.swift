//
//  ChartCollectionViewController.swift
//  Calliope App
//
//  Created by itestra on 27.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import DGCharts
import SwiftUI


class ChartCollectionViewController: UITableViewController, UIDocumentPickerDelegate, ChartCellDelegate {

    private lazy var charts: [Chart] = {
       return Chart.fetchChartsBy(projectsId: project?.id)
    }()


    private let reuseIdentifierProgram = "sensorRecording"

    var project: Project?
    var chartKvo: Any?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return charts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return createChartCell(tableView, indexPath)
    }

    private func createChartCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell: ChartViewCell
        cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifierProgram, for: indexPath) as! ChartViewCell
        cell.chart = charts[indexPath.item]
        cell.setupChartView()
        cell.delegate = self
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - 20, height: 400)
    }

    func deleteChart(of cell: ChartViewCell, chart: Chart?) {
        guard let chartId = chart?.id else {
            return
        }
        Chart.deleteChart(id: chartId)
        guard let project = project else {
            LogNotify.log("No project found")
            return
        }
        // Update charts list after deleting chart
        charts = Chart.fetchChartsBy(projectsId: project.id)

        // Remove chart from UI
        guard let newIndexPath = tableView.indexPath(for: cell) else {
            return
        }
        tableView.deleteRows(at: [newIndexPath], with: .fade)
    }

    func addChart() {
        guard let chart = Chart.insertChart(sensorType: nil, projectsId: project!.id) else {
            return
        }
        let newIndexPath = IndexPath(item: charts.count, section: 0)
        charts.append(chart)
        tableView.insertRows(at: [newIndexPath], with: .fade)
    }
}
