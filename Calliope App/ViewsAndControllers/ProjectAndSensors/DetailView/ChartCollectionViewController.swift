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
import CoreLocation


class ChartCollectionViewController: UITableViewController, UIDocumentPickerDelegate, ChartCellDelegate, CLLocationManagerDelegate {

    private lazy var charts: [Chart] = {
       return Chart.fetchChartsBy(projectsId: project?.id)
    }()


    private let reuseIdentifierProgram = "sensorRecording"

    var project: Project?
    var chartKvo: Any?
    
    required init?(coder: NSCoder) {
        locationManager = CLLocationManager()
        super.init(coder: coder)
        
        self.setupLocationManager()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        if isAuthorizedForLocation() {
            locationManager.startUpdatingLocation()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        locationManager.stopUpdatingLocation()
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
        cell.setupCellView()
        cell.mapview.isHidden = !isAuthorizedForLocation()
        cell.getLastLocation = getLastLocation
        cell.delegate = self
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - 20, height: 400) // TODO SKO: Adjust to hide till given?
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
    
    // #MARK: LOCATION RELEVANT FUNCTIONS
    
    private let COORDINATE_PRECISION = 4
    
    private var locationManager: CLLocationManager

    func setupLocationManager() {
        LogNotify.log("Init Location Updates; Auth status \(locationManager.authorizationStatus)")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        LogNotify.log("Maps will be \(self.isAuthorizedForLocation() ? "hidden" : "shown"), as Auth Status \(locationManager.authorizationStatus)")
        self.tableView.reloadData()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        LogNotify.log("Got new Location Data - Location Manager holds Long: \(self.locationManager.location?.coordinate.longitude ?? 0.0) Lat: \(self.locationManager.location?.coordinate.latitude ?? 0.0)")
    }

    private func getLastLocation() -> CLLocationCoordinate2D? {
        self.locationManager.location?.coordinate.rounded(toPlaces: COORDINATE_PRECISION) ?? nil
    }
    
    private func isAuthorizedForLocation() -> Bool {
        [CLAuthorizationStatus.authorizedAlways, CLAuthorizationStatus.authorizedWhenInUse].contains(self.locationManager.authorizationStatus)
    }
}
