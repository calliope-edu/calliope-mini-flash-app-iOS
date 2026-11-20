//
//  Ext.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 27.01.19.
//

import UIKit

extension Array where Element: Equatable {

	// Remove first collection element that is equal to the given `object`:
	mutating func remove(object: Element) -> Element? {
		if let index = firstIndex(of: object) {
			return remove(at: index)
		}
		return nil
	}
}

extension Character {
	var ascii: UInt8 {
		return UInt8(String(self).unicodeScalars.first!.value)
	}
}

extension String {
	var ascii: [UInt8] {
		return unicodeScalars.filter { $0.isASCII }.map { UInt8($0.value) }
	}
}

extension String.StringInterpolation {
	public mutating func appendInterpolation(_ value: Date, _ formatter: DateFormatter) {
		appendLiteral(formatter.string(from: value))
	}
}

extension UIColor {
	var coreImageColor: CIColor {
		return CIColor(color: self)
	}

	var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
		let coreImageColor = self.coreImageColor
		return (coreImageColor.red, coreImageColor.green, coreImageColor.blue, coreImageColor.alpha)
	}


	/// Converts a hexadecimal color string (rgb or rgba) to a UIColor object
	///
	/// - Parameter hex: a hexadecimal string of format "#<hexnumber>" where <hexnumber> must be a hexdadecimal number string with 6 (without alpha) or 8 letters.
	public convenience init?(hex: String) {
		let r: CGFloat
		let g: CGFloat
		let b: CGFloat
		let a: CGFloat

		guard hex.count == 7 || hex.count == 9, hex.hasPrefix("#") else { return nil }

		let start = hex.index(hex.startIndex, offsetBy: 1)
		let hexColor = String(hex[start...])

		let scanner = Scanner(string: hexColor)
		var hexNumber: UInt32 = 0

		guard scanner.scanHexInt32(&hexNumber) else { return nil }

		if hexColor.count == 6 {
			hexNumber = hexNumber << 8
		}

		r = CGFloat((hexNumber & 0xff00_0000) >> 24) / 255
		g = CGFloat((hexNumber & 0x00ff_0000) >> 16) / 255
		b = CGFloat((hexNumber & 0x0000_ff00) >> 8) / 255
		a = hexColor.count == 8 ? CGFloat(hexNumber & 0x0000_00ff) / 255 : 1.0

		self.init(red: r, green: g, blue: b, alpha: a)

		return
	}


	/// outputs a hexadecimal string with 6 letters or 8 if the color is not completely opaque, prefixed by #
	var hex: String {
		var r: CGFloat = 0
		var g: CGFloat = 0
		var b: CGFloat = 0
		var a: CGFloat = 0

		getRed(&r, green: &g, blue: &b, alpha: &a)

		let rgb: UInt32 =
			((UInt32)(r * 255) << 24)
			+ ((UInt32)(g * 255) << 16)
			+ ((UInt32)(b * 255) << 8)
			+ ((UInt32)(a * 255) << 0)

		if a == 1 {
			return String(format: "#%06x", rgb >> 8)
		} else {
			return String(format: "#%08x", rgb)
		}
	}
}

extension UInt16 {
	func hi() -> UInt8 {
		return UInt8((self >> 8) & 0xff)
	}

	func lo() -> UInt8 {
		return UInt8(self & 0xff)
	}
}

extension Int {
	func hi() -> UInt8 {
		return UInt8((self >> 8) & 0xff)
	}

	func lo() -> UInt8 {
		return UInt8(self & 0xff)
	}
}

func uint8(_ i: Int) -> UInt8 {
	if i < Int8.min || i > Int8.max {
		fatalError("out of range")
	}
	return UInt8(bitPattern: Int8(i))
}

func uint16(_ i: Int) -> UInt16 {
	if i < Int16.min || i > Int16.max {
		fatalError("out of range")
	}
	return UInt16(bitPattern: Int16(i))
}

func uint32(_ i: Int) -> UInt32 {
	if i < Int32.min || i > Int32.max {
		fatalError("out of range")
	}
	return UInt32(bitPattern: Int32(i))
}

func int8(_ i: Int) -> Int8 {
	if i < Int8.min || i > Int8.max {
		fatalError("out of range")
	}
	return Int8(i)
}

func int16(_ i: Int) -> Int16 {
	if i < Int16.min || i > Int16.max {
		fatalError("out of range")
	}
	return Int16(i)
}

func int32(_ i: Int) -> Int32 {
	if i < Int32.min || i > Int32.max {
		fatalError("out of range")
	}
	return Int32(i)
}
