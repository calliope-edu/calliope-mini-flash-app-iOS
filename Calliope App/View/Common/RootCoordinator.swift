//
//  RootCoordinator.swift
//  Calliope App
//
//  Created by Calliope on 14.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import Combine

final class RootCoordinator: ObservableObject {
    @Published var selectedTab = 0
    @Published var pendingEditorsRoute: EditorsAndProgramRoute?

    func navigateToEditor(_ route: EditorsAndProgramRoute) {
        pendingEditorsRoute = route
        selectedTab = 1
    }
}
