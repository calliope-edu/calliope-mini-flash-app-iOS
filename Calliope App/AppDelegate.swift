//
//  AppDelegate.swift
//  Calliope App
//
//  Created by Tassilo Karge on 23.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Settings.registerDefaults()
        Settings.resetSettingsIfRequired()
        Settings.updateAppVersion()
        Styles.setupGlobalFont()
        Styles.setGlobalTint()

        // Configure URLCache for offline MakeCode support
        // 50 MB memory cache, 500 MB disk cache
        let cache = URLCache(memoryCapacity: 50 * 1024 * 1024,
                            diskCapacity: 500 * 1024 * 1024,
                            diskPath: "makecode_cache")
        URLCache.shared = cache

        // Initialize iCloud container so the app folder appears in Files app
        StorageDirectory.shared.initializeCloudStorage()

        // Watch the hex storage directory for external changes (drag-and-drop
        // from Files app, iCloud sync) so the Programs list refreshes without
        // requiring an app restart.
        HexFileManager.startWatchingForExternalChanges()

        // Setting up Database
        let _ = DatabaseManager.shared

        return true
    }
}
