import CoreBluetooth

extension CBUUID {
	convenience init(hexString: String) {
		let hexa = Array(hexString)
		self.init(data: Data(stride(from: 0, to: hexString.count, by: 2).compactMap { UInt8(String(hexa[$0...$0.advanced(by: 1)]), radix: 16) }))
	}
}
