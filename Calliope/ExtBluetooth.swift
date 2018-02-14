import Foundation
import CoreBluetooth

extension CBManagerState {
    var text : String {
        switch self {
            case .unknown: return "unknown";
            case .resetting: return "resetting";
            case .unsupported: return "unsupported";
            case .unauthorized: return "unauthorized";
            case .poweredOff: return "poweredOff";
            case .poweredOn: return "poweredOn";
        }
    }
}
