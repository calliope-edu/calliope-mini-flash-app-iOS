import Foundation

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

extension String {
	var localized: String {
		return NSLocalizedString(self, comment: "")
	}
}

extension String {
	//TODO: subscript has been deprecated for a good reason, maybe replace

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

	func truncate(length: Int, trailing: String = "…") -> String {
		if self.count > length {
			return String(self.prefix(length)) + trailing
		} else {
			return self
		}
	}
}

extension String {
	func matches(regex: String) -> [String] {
		do {
			let regex = try NSRegularExpression(pattern: regex, options: [])
            let results = regex.matches(in: self, options: [], range: NSRange(self.startIndex..., in:self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
		} catch {
            LogNotify.log("error while matching regex \(regex) to string \(self.truncate(length: 80))")
			return []
		}
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
            let ascii = self.unicodeScalars.map { Character($0) }
            return Data(stride(from: 0, to: ascii.count, by: 2).compactMap { i in
                UInt8(String([ascii[i], ascii[i+1]]), radix: 16)
            })
		case .base64:
			return Data(base64Encoded: self)
		}
	}
}
