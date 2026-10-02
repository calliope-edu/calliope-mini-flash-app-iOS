import Foundation

extension URL {

    func asData() throws -> Data {

        let s = self.relativeString

        let data: Data
        let securityAccess = self.startAccessingSecurityScopedResource()

        defer {
            if securityAccess {
                self.stopAccessingSecurityScopedResource()
            }
        }

        if let later = s.components(separatedBy: "://?").last, let url = URL(string:later) {
            data = try Data(contentsOf: url)
        } else {
            return try Data(contentsOf: self)
        }

        return data
    }

    /// The Calliope website renders a layout tailored to the app — without the
    /// site navigation — when `menu=false` is present. Use this for pages the
    /// app displays inside its own web views.
    ///
    /// Only the website itself (`calliope.cc`, `www.calliope.cc`) is rewritten.
    /// The editors live on their own subdomains (makecode., python., blocks.,
    /// campus., go., app.) and are deliberately left untouched, as is any
    /// external host — for those this returns the URL unchanged.
    ///
    /// An existing query string and fragment are preserved: the parameter is
    /// inserted into the query, never appended after the fragment.
    var withCalliopeAppLayout: URL {
        guard let host = host?.lowercased(),
              host == "calliope.cc" || host == "www.calliope.cc",
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else {
            return self
        }

        var items = components.queryItems ?? []
        guard !items.contains(where: { $0.name == "menu" }) else { return self }
        items.append(URLQueryItem(name: "menu", value: "false"))
        components.queryItems = items

        return components.url ?? self
    }
}
