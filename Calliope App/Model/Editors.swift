import Foundation

enum NavigationTargetView {
    case externalWebView, internalWebView
}

struct EditorDownload {
    let name: String
    let url: URL
    let isHex: Bool
}

protocol Editor {
    var name: String { get }
    var url: URL? { get }
    func download(_ request: URLRequest) -> EditorDownload?
    func isBackNavigation(_ request: URLRequest) -> Bool
    func allowNavigation(_ request: URLRequest) -> Bool
    func getNavigationTargetViewForRequest(_ request: URLRequest) -> NavigationTargetView
}

extension Editor {
    func allowNavigation(_ request: URLRequest) -> Bool {
        return true
    }

    func getNavigationTargetViewForRequest(_ request: URLRequest) -> NavigationTargetView {
        return NavigationTargetView.externalWebView
    }
}

final class BlocksMiniEditor: Editor {
    public let name = "Calliope mini Blocks Editor"
    public lazy var url: URL? = {
        return URL(string: UserDefaults.standard.string(forKey: SettingsKey.blocksMiniEditorUrl.rawValue)!)
    }()
    func download(_ request: URLRequest) -> EditorDownload? {
        LogNotify.log("Blocks Editor does not download a file, but communicates directly with the mini")
        return nil
    }
    
    func isBackNavigation(_ request: URLRequest) -> Bool {
        return false
    }
}

final class MakeCode: Editor {
    public let name = "MakeCode"
    public lazy var url: URL? = {
        return URL(string: UserDefaults.standard.string(forKey: SettingsKey.makecodeUrl.rawValue)!)
    }()

    func download(_ request: URLRequest) -> EditorDownload? {
//        LogNotify.log("\(request)")
        guard let s = request.url?.absoluteString, s.matches(regex: "^([^:]*://)?data:application/octet-streamng").count == 1, let url = URL(string: s) else {
            guard
                let s = request.url?.absoluteString,
                s.matches(regex: "^([^:]*://)?data:application/x-calliope-hex").count
                    + s.matches(regex: "^([^:]*://)?data:application/x-microbit-hex").count == 1,
                let url = URL(string: s)
            else {
                return nil
            }
            return EditorDownload(name: "makecode-" + UUID().uuidString, url: url, isHex: true)
        }
        return EditorDownload(name: "makecode-" + UUID().uuidString, url: url, isHex: false)
    }

    func isBackNavigation(_ request: URLRequest) -> Bool {
        return request.url?.host?.matches(regex: "^calliope.cc").count ?? 0 > 0
    }
}

// https://lab.open-roberta.org/c0d66d4c-5cc9-4ed9-9b7d-6940aa291f4a
final class RobertaEditor: Editor {
    public let name = "Open Roberta NEPO®"
    public lazy var url: URL? = {
        return URL(string: UserDefaults.standard.string(forKey: SettingsKey.robertaUrl.rawValue)!)
    }()

    func allowNavigation(_ request: URLRequest) -> Bool {
        guard let url = request.url else {
            return true
        }
        let s = url.absoluteString
        let matches = s.matches(regex: "^data:text/xml")
        return matches.count == 0
    }

    func getNavigationTargetViewForRequest(_ request: URLRequest) -> NavigationTargetView {
        guard let url = request.url, let robertaEditorUrlPrefix = UserDefaults.standard.string(forKey: SettingsKey.robertaUrl.rawValue) else {
            return NavigationTargetView.externalWebView
        }

        if (url.absoluteString.hasPrefix(robertaEditorUrlPrefix)) {
            return NavigationTargetView.internalWebView
        }

        return NavigationTargetView.externalWebView
    }


    func download(_ request: URLRequest) -> EditorDownload? {
        guard let url = request.url else {
            return nil
        }
        let s = url.absoluteString
        let matches = s.matches(regex: "^data:text/(?:hex|xml)")
        guard matches.count == 1 else {
            return nil
        }
        return EditorDownload(name: "roberta-" + UUID().uuidString, url: url, isHex: true)
    }

    func isBackNavigation(_ request: URLRequest) -> Bool {
        return request.url?.host?.matches(regex: "roberta-home").count ?? 0 > 0
    }
}

final class MicroPython: Editor {
    public let name = "MicroPython"
    public lazy var url: URL? = {
        return URL(string: UserDefaults.standard.string(forKey: SettingsKey.microPythonUrl.rawValue)!)
    }()
   

    
    func download(_ request: URLRequest) -> EditorDownload? {
        LogNotify.log("MicroPython uses different path and this should not have been called")
        return nil
    }
    
    func isBackNavigation(_ request: URLRequest) -> Bool {
        return false
    }
    
}

/// Resolves the routes of the configured Calliope Campus deployment.
///
/// The campus home and every campus-hosted editor flavour live on the SAME
/// deployment, so they all derive from the single `campusUrl` preference —
/// bumping the deployment is then one edit (`Settings.defaultCampusUrl`)
/// instead of one per editor, and the set can never end up half-migrated.
enum CampusRoute {

    /// Absolute URL of `path` ("" = the campus home) on the configured campus.
    ///
    /// Only the ORIGIN of the stored preference is used; any path, query or
    /// fragment it carries is dropped. That is deliberate: installs from before
    /// the campus gained its editor routes have a stored `campusUrl` ending in
    /// `/blocks`, and appending to it would yield `/blocks/blocks`. Taking the
    /// origin also means the deployment bump reaches those installs, which
    /// `UserDefaults.register(defaults:)` alone would not — a value the user (or
    /// an older build) has written wins over a registered default forever.
    static func url(path: String) -> URL? {
        guard let configured = UserDefaults.standard.string(forKey: SettingsKey.campusUrl.rawValue),
              var components = URLComponents(string: configured),
              components.scheme != nil, components.host != nil
        else {
            return nil
        }
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = trimmed.isEmpty ? "" : "/" + trimmed
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

/// An editor served by the Calliope Campus deployment.
///
/// These drive BLE, flashing and raw GATT through the native-proxy bridge
/// (`CalliopeProxyMessageHandler`) rather than the legacy download-capture
/// path, so `EditorViewController` attaches the bridge to any editor conforming
/// to this protocol — one gate for the campus home and all of its flavours.
protocol CampusBridgedEditor: Editor {
    /// Route under the campus origin. "" is the campus home.
    var campusPath: String { get }
}

extension CampusBridgedEditor {
    var url: URL? {
        return CampusRoute.url(path: campusPath)
    }

    /// Campus never hands a file to the app on the flash path — the bridge does
    /// that. The MakeCode matcher stays wired up because the campus-hosted
    /// MakeCode flavour can still trigger a classic hex download (e.g. "save to
    /// computer"), and capturing it is strictly better than dropping it.
    func download(_ request: URLRequest) -> EditorDownload? {
        return MakeCode().download(request)
    }

    func isBackNavigation(_ request: URLRequest) -> Bool {
        return false
    }
}

final class CampusEditor: CampusBridgedEditor {
    public let name = "Calliope Campus"
    public let campusPath = ""
}

final class CampusBlocksEditor: CampusBridgedEditor {
    public let name = "Campus Blocks"
    public let campusPath = "blocks"
}

final class CampusMakeCodeEditor: CampusBridgedEditor {
    public let name = "Campus MakeCode"
    public let campusPath = "makecode"
}

final class CampusPythonEditor: CampusBridgedEditor {
    public let name = "Campus Python"
    public let campusPath = "python"
}

final class ArcadeEditor: Editor {
    public let name = "MakeCode Arcade"
    public lazy var url: URL? = {
        return URL(string: "https://arcade.makecode.com")
    }()
    
    func download(_ request: URLRequest) -> EditorDownload? {
        guard let s = request.url?.absoluteString else {
            return nil
        }
        
        // Arcade Base64 Format (data:undefined;base64,...)
        if s.matches(regex: "^([^:]*://)?data:undefined;base64,").count == 1,
           let url = URL(string: s) {
            LogNotify.log("ArcadeEditor: Matched undefined;base64 format!")
            return EditorDownload(name: "arcade-" + UUID().uuidString, url: url, isHex: true)
        }
        
        // Standard Hex-Format (wie bei normalem MakeCode)
        if s.matches(regex: "^([^:]*://)?data:application/x-calliope-hex").count == 1 ||
           s.matches(regex: "^([^:]*://)?data:application/x-microbit-hex").count == 1,
           let url = URL(string: s) {
            return EditorDownload(name: "arcade-" + UUID().uuidString, url: url, isHex: true)
        }
        
        // Octet-Stream Format
        if s.matches(regex: "^([^:]*://)?data:application/octet-stream").count == 1,
           let url = URL(string: s) {
            return EditorDownload(name: "arcade-" + UUID().uuidString, url: url, isHex: true)
        }
        
        return nil
    }
    
    func isBackNavigation(_ request: URLRequest) -> Bool {
        // Keine automatische Zurück-Navigation
        return false
    }
    
    func allowNavigation(_ request: URLRequest) -> Bool {
        return true
    }
    
    func getNavigationTargetViewForRequest(_ request: URLRequest) -> NavigationTargetView {
        guard let url = request.url else {
            return NavigationTargetView.externalWebView
        }
        
        // Interne Navigation für Arcade und MakeCode Seiten
        if url.host?.contains("arcade.makecode.com") == true ||
           url.host?.contains("makecode.com") == true {
            return NavigationTargetView.internalWebView
        }
        
        return NavigationTargetView.externalWebView
    }
}

extension Editor {
    public func isBlob(_ url: URL) -> Bool {
        return url.absoluteString.matches(regex: "^blob:").count == 1
    }
}
