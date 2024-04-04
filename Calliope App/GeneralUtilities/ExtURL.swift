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
}
