import Foundation
import UIKit

extension UIDevice {

    var model: String {
        get {
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            return machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else {
                    return identifier
                }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
        }
    }

    /// True if the device is running in Shared iPad mode (Managed Apple ID, e.g. ASM/ASE).
    ///
    /// Detection priority:
    /// 1. **MDM Managed App Configuration**: admins push a key `sharedIPad` (Bool)
    ///    via Managed App Config; we read it from `com.apple.configuration.managed`.
    /// 2. **Manual override**: `UserDefaults` key `sharedIPadOverride` (Bool) — useful for
    ///    development/testing without an MDM.
    ///
    /// On Shared iPad the Files app picker silently rejects folder selections on
    /// mounted external USB volumes (e.g. the Calliope MAINTENANCE/MINI drive).
    /// The app uses this flag to switch the USB flashing flow to a per-flash
    /// export picker, which works in the Shared iPad sandbox.
    var isSharedIPad: Bool {
        if let override = UserDefaults.standard.object(forKey: "sharedIPadOverride") as? Bool {
            return override
        }
        if let managed = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed"),
           let flag = managed["sharedIPad"] as? Bool {
            return flag
        }
        return false
    }

    var hasUSBC: Bool {
        get {
            let pattern = "([A-z]+)(\\d+),(\\d+)"
            let regex = try! NSRegularExpression(pattern: pattern)
            if let match = regex.firstMatch(in: self.model, range: NSMakeRange(0, self.model.count)) {
                if let groupRangeModelName = Range(match.range(at: 1), in: self.model),
                   let groupRangeModelMajorVersion = Range(match.range(at: 2), in: self.model),
                   let groupRangeModelMinorVersion = Range(match.range(at: 3), in: self.model) {
                    let modelName = self.model[groupRangeModelName], modelMajorVersion = UInt8(self.model[groupRangeModelMajorVersion]) ?? 0, modelMinorVersion = UInt8(self.model[groupRangeModelMinorVersion]) ?? 0

                    if modelName == "iPhone" && ((modelMajorVersion > 15) || (modelMajorVersion == 15 && modelMinorVersion > 3)) {
                        return true
                    }
                    return modelName == "iPad" && (modelMajorVersion == 8 || modelMajorVersion >= 13)

                }
            }

            return false
        }
    }

}
