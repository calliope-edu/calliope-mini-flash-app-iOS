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
                .toolbar(.hidden, for: .tabBar)
        case .dataLogger(let url):
            DataLoggerDetailView(url: url)
        case .infoWebView(let url):
            PopupEditorWebView(editor: MakeCode(url: url), alertPublisher: viewModel)
                .toolbar(.hidden, for: .tabBar)
        case .dataLoggerInfo:
            DataLoggerInfoView(navigator: navigator)
        case .projectsInfo:
            ProjectsInfoView(navigator: navigator)
        }
    }
}
