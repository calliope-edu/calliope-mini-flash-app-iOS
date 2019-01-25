import Foundation

extension String {

    subscript (i: Int) -> Character {

        // wraps out of bounds indices
        let j = i % self.count

        // wraps negative indices
        let x = j < 0 ? j + self.count : j

        guard x != 0 else {
	    return self.first!
        }

        guard x != count - 1 else {
	    return self.last!
        }

        return self[self.index(self.startIndex, offsetBy: x)]
    }

    subscript (r: Range<Int>) -> String {
        let lb = r.lowerBound
        let ub = r.upperBound

        guard lb != ub else { return String(self[lb]) }

        return String(self[self.index(self.startIndex, offsetBy: lb)..<self.index(self.startIndex, offsetBy: ub)])
    }

    subscript (r: CountableClosedRange<Int>) -> String {
        return self[r.lowerBound..<r.upperBound + 1]
    }
}

extension String {

    enum ExpandedEncoding {
        case hex
        case base64
    }

    func toData(using encoding: ExpandedEncoding) -> Data? {
        switch encoding {
        case .hex:
	    guard self.count % 2 == 0 else { return nil }
            var data = Data()
            var hi: Character = "0"
            var lo: Character = "0"
	    for (index, character) in self.enumerated() {
                if index % 2 == 0 {
                    hi = character
                } else {
                    lo = character
                    guard let byte = UInt8(String([hi, lo]), radix: 16) else { return nil }
                    data.append(byte)
                }
            }
            return data
        case .base64:
            return Data(base64Encoded: self)
        }
    }
}

extension String {
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }
}

extension String {
    func matches(regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [])
            let nsString = self as NSString
            let results = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
            var match = [String]()
            for result in results {
                for i in 0..<result.numberOfRanges {
                    match.append(nsString.substring( with: result.range(at: i) ))
                }
            }
            return match
        } catch {
            return []
        }
    }
}

extension String {
    /// return the localized string from self or self
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

extension String {

    func truncate(length: Int, trailing: String = "…") -> String {
	if self.count > length {
	    return String(self.prefix(length)) + trailing
        } else {
            return self
        }
    }
}
