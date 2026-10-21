//
//  Router.swift
//  Calliope App
//
//  Created by Calliope on 15.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

final class Router<RouteType: Hashable>: ObservableObject {
    @Published var path: [RouteType] = []

    func push(_ route: RouteType) {
        path.append(route)
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
