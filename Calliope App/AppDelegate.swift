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

        HexFileManager.startWatchingForExternalChanges()

        // Setting up Database
        let _ = DatabaseManager.shared

        return true
    }
}


/// UIScene life cycle for the single window the app uses.
///
/// Deliberately kept next to `AppDelegate` so both halves of the life cycle are
/// visible in one place; the window and its root view controller are created by
/// UIKit from the storyboard named in `UISceneStoryboardFile`.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        Styles.applyTint(to: window)

        // A cold launch triggered by opening a file or a universal link delivers
        // the payload here instead of through the per-event callbacks below.
        for context in connectionOptions.urlContexts {
            appDelegate?.importHexFile(at: context.url)
        }
        if let userActivity = connectionOptions.userActivities.first {
            appDelegate?.continueUserActivity(userActivity,
                                              rootViewController: window?.rootViewController)
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        LogNotify.log("App Entered Background")
        MatrixConnectionViewController.instance?.moveToBackground()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        LogNotify.log("App Entered Foreground")
        MatrixConnectionViewController.instance?.moveToForeground()
        // Re-arm the storage watcher and trigger one immediate refresh — covers
        // the case where files were added/removed via Files app while we were
        // backgrounded (the watcher's fd may have been suspended by the system).
        HexFileManager.startWatchingForExternalChanges()
        NotificationCenter.default.post(name: NotificationConstants.hexFileChanged, object: nil)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            appDelegate?.importHexFile(at: context.url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        appDelegate?.continueUserActivity(userActivity,
                                          rootViewController: window?.rootViewController)
    }
}
