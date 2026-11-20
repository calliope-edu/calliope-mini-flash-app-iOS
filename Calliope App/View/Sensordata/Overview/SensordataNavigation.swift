//
//  SensordataNavigation.swift
//  Calliope App
//
//  Created by Calliope on 11.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

protocol SensordataNavigator {
    func push(_ route: ProjectAndSensorsRoute)
    func pop()
}

extension Router: SensordataNavigator where RouteType == ProjectAndSensorsRoute {}

struct SensordataRouteView<ViewModelType: SensorDataViewModelProtocol & ObservableObject & Alertable>: View {
    let route: ProjectAndSensorsRoute
    let navigator: any SensordataNavigator
    @ObservedObject var viewModel: ViewModelType
    @Environment(\.deviceConnection) private var connection
    @Environment(\.documentStorage) private var documentStorage

    var body: some View {
        switch route {
        case .project(let id):
            ProjectDetailView(projectID: id, connection: connection, documentStorage: documentStorage, onDelete: { navigator.pop() })
        case .dataLogger(let url):
            DataLoggerDetailView(url: url)
                .subpageTitle(Text("Data Logger"))
        case .infoWebView(let url):
            PopupEditorWebView(editor: MakeCode(url: url), alertPublisher: viewModel)
                .subpageTitle(Text(verbatim: "MakeCode"))
        case .dataLoggerInfo:
            DataLoggerInfoView(navigator: navigator)
                .subpageTitle(Text("Data Logger"))
        case .projectsInfo:
            ProjectsInfoView(navigator: navigator)
                .subpageTitle(Text("LIVE SENSOR DATA"))
        }
    }
}
