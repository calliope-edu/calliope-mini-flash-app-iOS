//
//  CalliopeApp.swift
//  Calliope App
//
//  Created by Calliope on 14.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

@main
struct CalliopeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
