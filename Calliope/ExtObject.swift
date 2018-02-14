import Foundation
import ObjectiveC

extension NSObject {

    fileprivate struct AssociatedKeys {
        static var References = "tc_disposeBag"
    }

    func ref(_ obj: Any) {
        if var references = objc_getAssociatedObject(self, &AssociatedKeys.References) as? [Any] {
            references.append(obj)
        } else {
            let references: [Any] = [obj]
            objc_setAssociatedObject(self, &AssociatedKeys.References, references, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension NSObject {

    var className: String {
        return String(describing: type(of: self))
    }

    class var className: String {
        return String(describing: self)
    }
}
