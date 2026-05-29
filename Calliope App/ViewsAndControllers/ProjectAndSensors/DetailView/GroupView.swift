//
//  ChartView.swift
//  Calliope App
//
//  Created by Calliope on 08.05.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Charts
import Foundation
import MapKit
import SwiftUI

struct GroupView: View {
    @ObservedObject var viewModel: GroupViewModel

    var body: some View {
        VStack {
            ForEach(viewModel.chartViewModels) { chartViewModel in
                ChartView(
                    viewModel: chartViewModel,
                    onRemoveTapped: {
                        viewModel.deleteChart(chart: chartViewModel.chart)
                    }
                )
            }

            HStack {
                Spacer()
                addSensorButton
                Spacer()
            }

            MapView(viewModel: viewModel)
        }.padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("calliope-turqoise"))
            )
            .padding(.horizontal)

    }

    var addSensorButton: some View {
        IconButton(
            imageSystemName: "plus.circle",
            action: viewModel.addNewSensor,
            rotation: 0,
            iconColor: Color(.white),
            backgroundColor: Color(.white).opacity(0)
        )
    }
}

struct MapView: View {
    @ObservedObject var viewModel: GroupViewModel

    private var region: Binding<MKCoordinateRegion> {
        Binding {
            viewModel.region
        } set: { region in
            DispatchQueue.main.async {
                viewModel.region = region
            }
        }
    }

    var body: some View {
        ZStack {
            Map(
                coordinateRegion: region,
                annotationItems: Array(viewModel.uniqueLocations)
            ) { place in
                MapAnnotation(coordinate: place.location) {
                    Circle().frame(width: 20, height: 20)
                }
            }
            .onAppear {
                viewModel.calculateCenterRegion()
            }
            .frame(height: 300)
            .cornerRadius(12)

            Text("\(viewModel.uniqueLocations.count) unique locations")
                .padding()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topTrailing
                )

            IconButton(
                imageSystemName: "scope",
                action: viewModel.calculateCenterRegion,
                rotation: 0,
                iconColor: Color(.black),
                backgroundColor: Color(.white)
            ).padding()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottomTrailing
                )
        }
    }
}

