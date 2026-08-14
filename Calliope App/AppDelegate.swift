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

        // Setting up Database
        let _ = DatabaseManager.shared

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}
