import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        //Device.current = Device(name: "azvu", identifier: uuid_peripheral_calliope)

        LOG("> \(Application.identifier) \(Application.version) \(Application.build) \(Application.revision)")

        Styles.apply()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

        if url.isFileURL {
            do {
                if let name = url.lastPathComponent.split(separator: ".").map(String.init).first {
                    let data = try url.asData()
                    let file = try HexFileManager.store(name: "received-" + name, data: data)
                    LOG("received \(file)")
                }
            } catch {
                ERR("failed to receive \(url)")
            }
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }


}

