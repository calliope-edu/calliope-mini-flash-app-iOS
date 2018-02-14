import Foundation

extension URL {

    func asData() throws -> Data {

        let s = self.absoluteString

        if let later = s.components(separatedBy: "://?").last, let url = URL(string:later) {
            return try Data(contentsOf: url)
        } else {
            return try Data(contentsOf: self)
        }

//        if let later = s.components(separatedBy: "base64,").last, let data = Data(base64Encoded: later) {
//            return data
//        } else {
//            return try Data(contentsOf: self)
//        }
    }
}
