//
//  AppDelegate.swift
//  Calliope App
//
//  Created by Tassilo Karge on 23.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Settings.registerDefaults()
        Settings.resetSettingsIfRequired()
        Settings.updateAppVersion()
        Styles.setupGlobalFont()
        Styles.setGlobalTint()

        // Setting up Database
        let _ = DatabaseManager.shared
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        LogNotify.log("App Entered Background")
        MatrixConnectionViewController.instance.moveToBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        LogNotify.log("App Entered Foreground")
        MatrixConnectionViewController.instance.moveToForeground()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


    //MARK: opening Hex files

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

        if url.isFileURL && url.pathExtension.lowercased() == "hex" {
            LogNotify.log("received \(url.lastPathComponent)")
            guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
                fatalError(NSLocalizedString("No root view controller for presenting File Save UI found", comment: ""))
            }
            HexFileStoreDialog.showStoreHexUI(
                controller: viewController, hexFile: url,
                notSaved: { error in
                    return  //TODO: handle error
                }
            ) { savedFile in
                return  //TODO: handle file saved
            }

            return true
        }

        return false
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let rootViewController = window?.rootViewController, let tabBarController = findTabBarController(from: rootViewController),
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
        let viewController = storyboard.instantiateViewController(withIdentifier: "EditorViewControllerInEditorAndPrograms") as? EditorViewController

        guard let viewController = viewController else {
            LogNotify.log("Could not create new ViewController")
            return nil
        }

        #if DEBUG
        let originialUrl = url.absoluteString
        let url = URL.init(string: "https://makecode.calliope.cc\(url.path)?\(url.query ?? "")#\(url.fragment ?? "")")
        LogNotify.log("Redirected development domain (\(originialUrl)) to makecode (\(url?.absoluteString ?? "none?"))")
        #endif

        let editor = MakeCode()
        editor.url = url
        viewController.editor = editor

        return viewController
    }
}
