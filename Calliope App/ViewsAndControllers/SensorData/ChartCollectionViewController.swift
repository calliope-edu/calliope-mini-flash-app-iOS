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


class ChartCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UIDocumentPickerDelegate, ChartCellDelegate {

    private lazy var charts: [Chart] = { () -> [Chart] in
        do { return Chart.fetchChartsBy(projectsId: project?.id)! }
        catch { fatalError("could not load files \(error)") }
    }()


    private let reuseIdentifierProgram = "sensorRecording"
    
    var project: Project?
    var chartKvo: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()
                    
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return charts.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: UICollectionViewCell
        cell = createChartCell(collectionView, indexPath)
        return cell
    }
    
    private func createChartCell(_ collectionView: UICollectionView, _ indexPath: IndexPath) -> UICollectionViewCell {
        //TODO: Configure the cell
        let cell: ChartViewController
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath) as! ChartViewController
        cell.chart = charts[indexPath.item]
        cell.setChart(values: [])
        cell.delegate = self
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return CGSize(width: collectionView.frame.width - 40, height: 400)
    }
    
    func deleteChart(of cell: ChartViewController, chart: Chart?) {
        guard let chartId = chart?.id else {
            return
        }
        Chart.deleteChart(id: chartId)
        charts.removeAll { deleteChart in
            guard let deleteId = deleteChart.id else {
                return false
            }
            return deleteId == chartId
        }
        // Remove chart from UI
        guard let newIndexPath = collectionView.indexPath(for: cell) else {
            print("ERROR")
            return
        }
        collectionView.deleteItems(at: [newIndexPath])
    }
    
    func addChart() {
        print("Adding New Sensor")
        guard let chart = Chart.insertChart(name: "New chart", values: "", projectsId: project!.id) else {
            return
        }
        let newIndexPath = IndexPath(item: charts.count, section: 0)
        charts.append(chart)
        collectionView.insertItems(at: [newIndexPath])
        
    }
}
