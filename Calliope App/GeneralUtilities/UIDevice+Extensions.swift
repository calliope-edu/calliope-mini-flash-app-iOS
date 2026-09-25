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
    /// The USB flashing flow itself — switch, folder picker, copy — is identical
    /// to a personal iPad. This flag only adds the two Shared-iPad specifics:
    /// a one-time heads-up alert before the first pick
    /// (`CalliopeDiscovery.initializeConnectionToUsbCalliope`), and dropping the
    /// connection plus switching USB back off after every copy
    /// (`MatrixConnectionViewController.resetUsbConnectionAfterCopy`), because
    /// the picked volume's authorization does not survive a copy here.
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

    /// True when the app cannot obtain a writable folder URL for a mounted USB
    /// volume and therefore has to let the user pick the destination for every
    /// single flash through an export picker:
    ///
    /// - **Shared iPad:** the managed sandbox silently refuses the folder pick —
    ///   tapping "Öffnen" does nothing at all.
    /// - **iPadOS < 26:** the picker puts a search field where the
    ///   "Öffnen"/"Auswählen" button belongs, so the volume can never be
    ///   confirmed.
    ///
    /// Single source of truth for both the picker route
    /// (`CalliopeDiscovery.initializeConnectionToUsbCalliope`) and the teardown
    /// after a copy (`MatrixConnectionViewController.resetUsbConnectionAfterCopy`),
    /// so the two can never disagree.
    var usbNeedsExportPicker: Bool {
        isSharedIPad || ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26
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
