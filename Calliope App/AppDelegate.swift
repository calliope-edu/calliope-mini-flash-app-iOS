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

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController, let tabBarController = findTabBarController(from: rootViewController),
            let targetViewController = setupTargetViewController(targetActivity: userActivity)
        {
            pushNewViewController(from: tabBarController, for: targetViewController)
            return true
        }

        LogNotify.log("Either rootViewController, tabBarController or the targetViewController could not have been established")
        return false
    }


    private func findTabBarController(from viewController: UIViewController) -> UITabBarController? {
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController
        }

        if let navigationController = viewController as? UINavigationController {
            for vc in navigationController.viewControllers {
                if let tabBarController = findTabBarController(from: vc) {
                    return tabBarController
                }
            }
        }

        for child in viewController.children {
            if let tabBarController = findTabBarController(from: child) {
                return tabBarController
            }
        }

        LogNotify.log("Could not find tabBar. This should not happen.")
        return nil
    }

    private func pushNewViewController(from tabBarController: UITabBarController, for targetViewController: UIViewController) {
        guard let selectedNavController = tabBarController.selectedViewController as? UINavigationController else {
            LogNotify.log("The selected view controller is not a UINavigationController.")
            return
        }

        selectedNavController.pushViewController(targetViewController, animated: true)
    }

    private func setupTargetViewController(targetActivity userActivity: NSUserActivity) -> UIViewController? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else {
            LogNotify.log("Unable to setup target, as activity not supported")
            return nil
        }

        // possibly extend this to some logic, if we going to be supporting more universallink targets
        return setupMakeCodeEditorViewController(for: url)
    }

    private func setupMakeCodeEditorViewController(for url: URL) -> UIViewController? {
        let storyboard = UIStoryboard(name: "EditorAndPrograms", bundle: Bundle.main)
        let viewController = storyboard.instantiateViewController(withIdentifier: "EditorViewController") as? EditorViewController

        guard let viewController = viewController else {
            LogNotify.log("Could not create new ViewController")
            return nil
        }

        #if DEBUG
        var url = url
        if url.host != "makecode.calliope.cc" {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "makecode.calliope.cc"
            components.path = url.path
            components.query = url.query
            components.fragment = url.fragment
            let originalUrl = url.absoluteString
            if let redirectedUrl = components.url {
                url = redirectedUrl
                LogNotify.log("Redirected development domain (\(originalUrl)) to makecode (\(url.absoluteString))")
            }
        }
        #endif

        let editor = MakeCode()
        editor.url = url
        viewController.editor = editor

        return viewController
    }
}
