import Foundation

struct EditorDownload {
    let name: String
    let url: URL
}

protocol Editor {
    var name: String { get }
    var url: URL { get }
    func download(_ request: URLRequest) -> EditorDownload?
}

// https://miniedit.calliope.cc/86184610-93de-11e7-a0b1-cd0ef2962ca5
final class MiniEditor: Editor {
    public let name = "Calliope mini Editor"
    public let url = URL(string: "https://miniedit.calliope.cc/")!

    func download(_ request: URLRequest) -> EditorDownload? {
        guard let url = request.url else { return nil }
        let s = url.absoluteString
        let matches = s.matches(regex: "https://[^/]+/(\\w+-\\w+-\\w+-\\w+-\\w+)")
        guard matches.count == 2 else { return nil }
        return EditorDownload(name: "mini-" + matches[1], url: url)
    }
}

// https://pxt.calliope.cc/
final class MicrobitEditor: Editor {
    public let name = "MakeCode"
    public let url = URL(string: "https://makecode.calliope.cc/")!

    func download(_ request: URLRequest) -> EditorDownload? {
        guard let s = request.url?.absoluteString else { return nil }
        let matches = s.matches(regex: "^data:application/x-calliope-hex")
        guard matches.count == 1 else { return nil }
        guard let url = URL(string:s) else { return nil }
        return EditorDownload(name: "makecode-" + UUID().uuidString, url: url)
    }
}

// https://lab.open-roberta.org/c0d66d4c-5cc9-4ed9-9b7d-6940aa291f4a
final class RobertaEditor: Editor {
    public let name = "Open Roberta NEPO®"
    public let url = URL(string: "https://lab.open-roberta.org/")!


    func download(_ request: URLRequest) -> EditorDownload? {
        guard let url = request.url else { return nil }
        let s = url.absoluteString
        let matches = s.matches(regex: "^data:")
        guard matches.count == 1 else { return nil }
        return EditorDownload(name: "roberta-" + UUID().uuidString, url: url)
    }
}


