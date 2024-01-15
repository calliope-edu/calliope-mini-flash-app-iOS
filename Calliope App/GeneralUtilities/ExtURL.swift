import Foundation

extension URL {

    func asData() throws -> Data {

        let s = self.relativeString
        
        let data: Data
        guard self.startAccessingSecurityScopedResource() else {
            if let later = s.components(separatedBy: "://?").last, let url = URL(string:later) {
                data = try Data(contentsOf: url)
            } else {
                return try Data(contentsOf: self)
            }
            return data
        }
        if let later = s.components(separatedBy: "://?").last, let url = URL(string:later) {
            data = try Data(contentsOf: url)
        } else {
            return try Data(contentsOf: self)
        }
        self.stopAccessingSecurityScopedResource()
        return data

//        if let later = s.components(separatedBy: "base64,").last, let data = Data(base64Encoded: later) {
//            return data
//        } else {
//            return try Data(contentsOf: self)
//        }
    }
}
