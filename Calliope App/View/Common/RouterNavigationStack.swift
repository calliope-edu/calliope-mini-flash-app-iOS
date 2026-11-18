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
    @Environment(\.subpageShownChanged) private var subpageShownChanged
    @ViewBuilder let root: () -> Root
    @ViewBuilder let destination: (RouteType) -> Destination

    var body: some View {
        NavigationStack(path: $router.path) {
            root()
                .navigationDestination(for: RouteType.self) { route in
                    destination(route)
                        .navigationBarTitleDisplayMode(.inline)
                        // Since iOS 26 the bar only gets a background from a scroll view below it unless one is set explicitly
                        .toolbarBackground(.bar, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                }
        }
        .statusBarHidden(!router.path.isEmpty)
        .toolbar(router.path.isEmpty ? .automatic : .hidden, for: .tabBar)
        .onChange(of: router.path.isEmpty) { isEmpty in
            subpageShownChanged(!isEmpty)
        }
    }
}
