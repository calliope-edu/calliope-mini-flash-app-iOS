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

    // MARK: UIScene life cycle

    /// Required since the app is built against the iOS 27 SDK: UIKit refuses to
    /// launch an app that still relies on the `UIApplicationDelegate`-only life
    /// cycle ("UIScene life cycle is required for apps built with this SDK").
    ///
    /// The per-scene callbacks — foreground/background, opened files, universal
    /// links — now live in `SceneDelegate` below. The app-wide one-time setup
    /// stays in `didFinishLaunchingWithOptions`, which is still the right place
    /// for it.
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration",
                             sessionRole: connectingSceneSession.role)
    }

    //MARK: opening Hex files

    /// Imports an externally opened hex file. Called from `SceneDelegate` — with
    /// the scene life cycle, `application(_:open:options:)` is no longer invoked.
    @discardableResult
    func importHexFile(at url: URL) -> Bool {

        if url.isFileURL && FileExtension(rawValue: url.pathExtension.lowercased()) == .hex {
            LogNotify.log("received \(url.lastPathComponent)")
            // Opening a file from Files/Spotlight can launch the app cold, so the
            // root view controller may not exist yet. This used to be a
            // `fatalError` on `keyWindow` (deprecated and nil at that moment),
            // which crashed the app instead of importing the file — retry on the
            // next run loop turns until the UI is up, then give up quietly.
            presentStoreHexUI(for: url, attemptsLeft: 20)
            return true
        }

        return false
    }

    /// Presents the save dialog for an externally opened hex file as soon as a
    /// view controller is available. `url` may be a security-scoped file owned by
    /// another app, so access is held while the dialog reads it.
    private func presentStoreHexUI(for url: URL, attemptsLeft: Int) {
        guard let controller = Self.topMostViewController() else {
            guard attemptsLeft > 0 else {
                LogNotify.log("No view controller available to present the hex import dialog")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.presentStoreHexUI(for: url, attemptsLeft: attemptsLeft - 1)
            }
            return
        }

        let accessed = url.startAccessingSecurityScopedResource()
        HexFileStoreDialog.showStoreHexUI(
            controller: controller, hexFile: url,
            notSaved: { error in
                if accessed { url.stopAccessingSecurityScopedResource() }
                if let error = error {
                    LogNotify.log("Importing \(url.lastPathComponent) failed: \(error.localizedDescription)")
                }
            }
        ) { _ in
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
    }

    /// Top-most presented view controller of the active window, without the
    /// deprecated `keyWindow`.
    private static func topMostViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// Handles a universal link. Called from `SceneDelegate` — with the scene
    /// life cycle, `application(_:continue:restorationHandler:)` is no longer
    /// invoked, and the window belongs to the scene rather than to this class.
    @discardableResult
    func continueUserActivity(_ userActivity: NSUserActivity, rootViewController: UIViewController?) -> Bool {
        if let rootViewController = rootViewController, let tabBarController = findTabBarController(from: rootViewController),
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
