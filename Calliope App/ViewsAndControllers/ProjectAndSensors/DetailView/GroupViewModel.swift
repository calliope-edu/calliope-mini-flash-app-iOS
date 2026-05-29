//
//  GroupViewModel.swift
//  Calliope App
//
//  Created by Calliope on 22.05.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import MapKit
import SwiftUI

class GroupViewModel: ObservableObject, Identifiable {
    var group: Group
    var openFileNameDialog: (@escaping (_ filename: String) -> Void) -> Void
    var deleteGroup: (_ groupId: Int64) -> Void
    @Published var chartViewModels: [ChartViewModel] = []

    @Published var uniqueLocations: Set<IdentifiableLocation> = Set<
        IdentifiableLocation
    >()
    @Published var region: MKCoordinateRegion = getDefaultRegion()

    init(
        group: Group,
        openFileNameDialog:
            @escaping (@escaping (_ filename: String) -> Void) -> Void,
        deleteGroup: @escaping (_ groupId: Int64) -> Void
    ) {
        self.group = group
        self.openFileNameDialog = openFileNameDialog
        self.deleteGroup = deleteGroup

        loadCharts()

        loadLocationsFromDatabase()
    }

    func loadCharts() {
        chartViewModels = []
        let charts = Chart.fetchChartsBy(groupsId: group.id)
        charts.forEach { chart in
            chartViewModels.append(
                ChartViewModel(
                    chart: chart,
                    openFileNameDialog: openFileNameDialog,
                    onNewLocation: onNewLocation
                )
            )
        }
    }

    func calculateCenterRegion() {
        if uniqueLocations.isEmpty {
            region = GroupViewModel.getDefaultRegion()
            return
        }

        var center = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        if uniqueLocations.count > 0 {
            for place in uniqueLocations {
                center.latitude += place.location.latitude
                center.longitude += place.location.longitude
            }
            center.latitude /= Double(uniqueLocations.count)
            center.longitude /= Double(uniqueLocations.count)
        }

        var maxDistanceFromCenter = 0.002
        let centerCL = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude
        )
        for place in uniqueLocations {
            let distance = centerCL.distance(
                from: CLLocation(
                    latitude: place.location.latitude,
                    longitude: place.location.longitude
                )
            )
            if distance > maxDistanceFromCenter {
                maxDistanceFromCenter = distance
            }
        }

        region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: maxDistanceFromCenter,
                longitudeDelta: maxDistanceFromCenter
            )
        )
    }

    static private func getDefaultRegion() -> MKCoordinateRegion {
        // shows Berlin by default
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.4050),
            span: MKCoordinateSpan(
                latitudeDelta: 0.1,
                longitudeDelta: 0.1
            )
        )
    }

    func loadLocationsFromDatabase() {
        uniqueLocations.removeAll()
        let charts = Chart.fetchChartsBy(groupsId: group.id)
        for chart in charts {
            let values = Value.fetchValuesBy(chartId: chart.id)
            for value in values {
                if value.lat != nil && value.long != nil {
                    uniqueLocations.insert(
                        IdentifiableLocation(lat: value.lat!, long: value.long!)
                    )
                }
            }
        }
    }

    func onNewLocation(location: IdentifiableLocation) {
        self.uniqueLocations.insert(location)
        self.calculateCenterRegion()
    }

    func deleteChart(chart: Chart) {
        Chart.deleteChart(id: chart.id)
        loadCharts()
        loadLocationsFromDatabase()
        if chartViewModels.isEmpty {
            guard let groupId = group.id else {
                LogNotify.log("Group id is nil. This should not happen.")
                return
            }
            deleteGroup(groupId)
        }
    }

    func addNewSensor() {
        guard let chart = Chart.insertChart(sensorType: nil, groupsId: group.id)
        else {
            return
        }
        withAnimation(nil) {  // disables an unideal animation of the add button
            chartViewModels.append(
                ChartViewModel(
                    chart: chart,
                    openFileNameDialog: openFileNameDialog,
                    onNewLocation: onNewLocation
                )
            )
        }
    }

    func onMapAnnotationTapped(location: IdentifiableLocation) {
        chartViewModels.forEach { $0.markValueForLocation(location: location) }
    }
}
