import Foundation
import CoreBluetooth

final class Device: NSObject, NSCoding {

    public let name: String
    public let identifier: UUID

    init(name: String, identifier: UUID) {
        self.name = name
        self.identifier = identifier
    }


    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "name") as? String ?? ""
        self.identifier = (decoder.decodeObject(forKey: "identifier") as! NSUUID!)! as UUID
    }

    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(identifier as NSUUID, forKey: "identifier")
    }


    fileprivate static let key = "foo"

    public static var current : Device? {
        set(newValue) {
            if let device = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: device)
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        get {
            if let data = UserDefaults.standard.data(forKey: key) {
                if let device = NSKeyedUnarchiver.unarchiveObject(with: data) as? Device {
                    return device
                }
            }
            return nil
        }
    }


//    public static func pair(identifier: UUID) -> Promise<CBPeripheral> {
//        return Promise<CBPeripheral>(in: .background, { resolve, reject, _ in
//            reject("nope")
//        })
//    }
//
//    public static func reboot(identifier: UUID) -> Promise<CBPeripheral> {
//        return Promise<CBPeripheral>(in: .background, { resolve, reject, _ in
//            reject("nope")
//        })
//    }
//
//    public static func upload(bin: Data, dat: Data, to peripheral: CBPeripheral) -> Promise<Void> {
//        return Promise<Void>(in: .background, { resolve, reject, _ in
//            reject("nope")
//        })
//    }

}
