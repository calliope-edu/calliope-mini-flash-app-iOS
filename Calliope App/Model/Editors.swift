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

final class CampusEditor: Editor {
    public let name = "Calliope Campus"
    public lazy var url: URL? = {
        return URL(string: UserDefaults.standard.string(forKey: SettingsKey.campusUrl.rawValue)!)
    }()
    
    func download(_ request: URLRequest) -> EditorDownload? {
        if let download = MakeCode().download(request) {
            return download
        }
        
        return nil
    }
    
    func isBackNavigation(_ request: URLRequest) -> Bool {
        return false
    }
    
    private func isBlob(_ url: URL) -> Bool {
        return url.absoluteString.matches(regex: "^blob:").count == 1
    }
}

extension Editor {
    public func isBlob(_ url: URL) -> Bool {
        return url.absoluteString.matches(regex: "^blob:").count == 1
    }
}
