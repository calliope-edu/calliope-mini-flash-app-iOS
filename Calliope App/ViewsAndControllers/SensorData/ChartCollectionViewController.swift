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
       return Chart.fetchChartsBy(projectsId: project?.id)!
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
        let cell: ChartViewCell
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath) as! ChartViewCell
        cell.chart = charts[indexPath.item]
        cell.setupChartView()
        cell.delegate = self
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return CGSize(width: collectionView.frame.width - 40, height: 400)
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
        charts = Chart.fetchChartsBy(projectsId: project.id)!

        // Remove chart from UI
        guard let newIndexPath = collectionView.indexPath(for: cell) else {
            print("ERROR")
            return
        }
        
        collectionView.deleteItems(at: [newIndexPath])
    }
    
    func addChart() {
        print("Adding New Sensor")
        //TODO: Hier noch einen vernünftigen default sensorType setzen
        guard let chart = Chart.insertChart(sensorType: .accelerometer, projectsId: project!.id) else {
            return
        }
        let newIndexPath = IndexPath(item: charts.count, section: 0)
        charts.append(chart)
        collectionView.insertItems(at: [newIndexPath])
        
    }
}
