import UIKit

extension Data {
	struct HexEncodingOptions: OptionSet {
		let rawValue: Int
		static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
	}

	func hexEncodedString(options: HexEncodingOptions = []) -> String {
		let hexDigits = Array((options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef").utf16)
		var chars: [unichar] = []
		chars.reserveCapacity(2 * count)
		for byte in self {
			chars.append(hexDigits[Int(byte / 16)])
			chars.append(hexDigits[Int(byte % 16)])
		}
		return String(utf16CodeUnits: chars, count: chars.count)
	}

	static func fromValue<T>(_ value: T) -> Data {
		return Swift.withUnsafeBytes(of: value) {
			Data($0)
		}
	}

	func padded(to size: Int, with paddingValue: UInt8) -> Data {
		guard self.count < size else {
			return self
		}

		let paddingNeeded = size - self.count
		let paddingData = Data(repeating: paddingValue, count: paddingNeeded)
		return self + paddingData
	}
}

protocol DataConvertible {
	init?(data: Data)
	var data: Data { get }
}

extension DataConvertible {
	init?(data: Data) {
		guard data.count == MemoryLayout<Self>.size else {
			return nil
		}
		self = data.withUnsafeBytes {
			$0.load(as: Self.self)
		}
	}

	var data: Data {
		return withUnsafeBytes(of: self) {
			Data($0)
		}
	}
}

protocol EndianDataConvertible: FixedWidthInteger {
	init?(littleEndianData: Data)
	var littleEndianData: Data { get }
}

extension EndianDataConvertible {
	init?(littleEndianData: Data) {
		guard littleEndianData.count == MemoryLayout<Self>.size else {
			return nil
		}
		self.init(littleEndian: (littleEndianData.withUnsafeBytes {
			$0.load(as: Self.self)
		}))
	}

	var littleEndianData: Data {
		return withUnsafeBytes(of: self.littleEndian) {
			Data($0)
		}
	}

	init?(bigEndianData: Data) {
		guard bigEndianData.count == MemoryLayout<Self>.size else {
			return nil
		}
		self.init(bigEndian: (bigEndianData.withUnsafeBytes {
			$0.load(as: Self.self)
		}))
	}

	var bigEndianData: Data {
		return withUnsafeBytes(of: self.bigEndian) {
			Data($0)
		}
	}
}

extension Int: EndianDataConvertible {
}

extension Int64: EndianDataConvertible {
}

extension Int32: EndianDataConvertible {
}

extension Int16: EndianDataConvertible {
}

extension Int8: EndianDataConvertible {
}

extension UInt: EndianDataConvertible {
}

extension UInt64: EndianDataConvertible {
}

extension UInt32: EndianDataConvertible {
}

extension UInt16: EndianDataConvertible {
}

extension UInt8: EndianDataConvertible {
}

extension Float: DataConvertible {
}

extension Double: DataConvertible {
}

