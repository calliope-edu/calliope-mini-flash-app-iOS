import Foundation

struct EditorDownload {
    let name: String
    let url: URL
}

protocol Editor {
    var name: String { get }
    var url: URL? { get }
    func download(_ request: URLRequest) -> EditorDownload?
}

// https://miniedit.calliope.cc/86184610-93de-11e7-a0b1-cd0ef2962ca5
final class MiniEditor: Editor {
    public let name = "Calliope mini Editor"
    public let url = URL(string: "/") //TODO: if used again, have URL in defaults

    init() {
        fatalError("MiniEditor not implemented currently")
    }
    
    func download(_ request: URLRequest) -> EditorDownload? {
        guard let url = request.url else { return nil }
        let s = url.absoluteString
        let matches = s.matches(regex: "https://[^/]+/(\\w+-\\w+-\\w+-\\w+-\\w+)")
        guard matches.count == 2 else { return nil }
        return EditorDownload(name: "mini-" + matches[1], url: url)
    }
}

final class MakeCode: Editor {
    public let name = "MakeCode"
	public lazy var url: URL? = {
		return URL(string: UserDefaults.standard.string(forKey: SettingsKey.makecodeUrl.rawValue)!)
	}()

    func download(_ request: URLRequest) -> EditorDownload? {
        guard
			let s = request.url?.absoluteString,
			s.matches(regex: "^data:application/x-calliope-hex").count
                + s.matches(regex: "^data:application/x-microbit-hex").count == 1,
			let url = URL(string:s) else { return nil }
        return EditorDownload(name: "makecode-" + UUID().uuidString, url: url)
    }
}

// https://lab.open-roberta.org/c0d66d4c-5cc9-4ed9-9b7d-6940aa291f4a
final class RobertaEditor: Editor {
    public let name = "Open Roberta NEPO®"
	public lazy var url: URL? = {
		return URL(string: UserDefaults.standard.string(forKey: SettingsKey.robertaUrl.rawValue)!)
	}()

    func download(_ request: URLRequest) -> EditorDownload? {
        guard let url = request.url else { return nil }
        let s = url.absoluteString
        let matches = s.matches(regex: "^data:")
        guard matches.count == 1 else { return nil }
        return EditorDownload(name: "roberta-" + UUID().uuidString, url: url)
    }
}


