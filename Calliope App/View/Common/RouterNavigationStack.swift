//
//  RouterNavigationStack.swift
//  Calliope App
//
//  Created by Calliope on 18.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

struct RouterNavigationStack<RouteType: Hashable, Root: View, Destination: View>: View {
    @ObservedObject var router: Router<RouteType>
    @ViewBuilder let root: () -> Root
    @ViewBuilder let destination: (RouteType) -> Destination

    var body: some View {
        NavigationStack(path: $router.path) {
            root()
                .navigationDestination(for: RouteType.self) { route in
                    destination(route)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.visible, for: .navigationBar)
                }
        }
        .statusBarHidden(!router.path.isEmpty)
    }
}
