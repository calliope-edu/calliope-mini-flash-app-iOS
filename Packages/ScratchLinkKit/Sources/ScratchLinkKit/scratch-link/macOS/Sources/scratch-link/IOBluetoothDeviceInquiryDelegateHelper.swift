import IOBluetooth

// Use this class to act as a IOBluetoothDeviceInquiryDelegate without conforming to NSObjectProtocol or inheriting NSObject.
// Usage:
// 1. Conform to SwiftIOBluetoothDeviceInquiryDelegate instead of IOBluetoothDeviceInquiryDelegateHelper
// 2. Create an instance of IOBluetoothDeviceInquiryDelegateHelper
// 3. Set the IOBluetoothDeviceInquiryDelegateHelper as the IOBluetoothDeviceInquiry's delegate
// 4. Set your SwiftIOBluetoothDeviceInquiryDelegate-conforming object as the IOBluetoothDeviceInquiryDelegateHelper's delegate
class IOBluetoothDeviceInquiryDelegateHelper: NSObject, IOBluetoothDeviceInquiryDelegate {
    weak var delegate: SwiftIOBluetoothDeviceInquiryDelegate?

    @available(OSX 10.4, *)
    func deviceInquiryStarted(_ sender: IOBluetoothDeviceInquiry!) {
        delegate?.deviceInquiryStarted?(sender)
    }

    @available(OSX 10.4, *)
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        delegate?.deviceInquiryDeviceFound?(sender, device: device)
    }

    @available(OSX 10.4, *)
    func deviceInquiryUpdatingDeviceNamesStarted(_ sender: IOBluetoothDeviceInquiry!, devicesRemaining: UInt32) {
        delegate?.deviceInquiryUpdatingDeviceNamesStarted?(sender, devicesRemaining: devicesRemaining)
    }

    @available(OSX 10.4, *)
    func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32) {
        delegate?.deviceInquiryDeviceNameUpdated?(sender, device: device, devicesRemaining: devicesRemaining)
    }

    @available(OSX 10.4, *)
    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        delegate?.deviceInquiryComplete?(sender, error: error, aborted: aborted)
    }
}

// This is a copy of IOBluetoothDeviceInquiryDelegate without NSObjectProtocol conformance.
@objc protocol SwiftIOBluetoothDeviceInquiryDelegate {
    @available(OSX 10.4, *)
    @objc optional func deviceInquiryStarted(_ sender: IOBluetoothDeviceInquiry!)

    @available(OSX 10.4, *)
    @objc optional func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!)

    @available(OSX 10.4, *)
    @objc optional func deviceInquiryUpdatingDeviceNamesStarted(_ sender: IOBluetoothDeviceInquiry!, devicesRemaining: UInt32)

    @available(OSX 10.4, *)
    @objc optional func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32)

    @available(OSX 10.4, *)
    @objc optional func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool)
}
