import UIKit

struct Application {

    private static let bundle = Bundle.main

    static let identifier = bundle.object(forInfoDictionaryKey: "CFBundleIdentifier") as! String
    static let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    static let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    static let revision = bundle.object(forInfoDictionaryKey: "CFBundleGetInfoString") as! String

}
