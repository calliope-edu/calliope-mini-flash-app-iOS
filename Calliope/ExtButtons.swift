import UIKit

fileprivate class ClosureSleeve<T> {
    let closure: (T) -> ()
    let attachTo: T

    init(attachTo: T, closure: @escaping (T) -> ()) {
        self.closure = closure
        self.attachTo = attachTo
        objc_setAssociatedObject(attachTo, "[\(arc4random())]", self, .OBJC_ASSOCIATION_RETAIN)
    }

    @objc func invoke() {
        closure(attachTo)
    }
}

extension UIButton {
    func addAction(for controlEvents: UIControl.Event, _ action: @escaping (UIButton) -> ()) {
        let sleeve = ClosureSleeve<UIButton>(attachTo: self, closure: action)
        addTarget(sleeve, action: #selector(ClosureSleeve<UIButton>.invoke), for: controlEvents)
    }
}

extension UIBarButtonItem {
    func addAction(_ action: @escaping (UIBarButtonItem) -> ()) {
        let sleeve = ClosureSleeve<UIBarButtonItem>(attachTo: self, closure: action)
        self.target = sleeve
        self.action = #selector(ClosureSleeve<UIBarButtonItem>.invoke)
    }
}

extension UIBarButtonItem {
    class func itemWith(image: UIImage?, title: String?, target: AnyObject, action: Selector) -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.setImage(image, for: .normal)
        button.setTitle(title, for: .normal)
        button.sizeToFit()
//        button.frame = CGRect(x: 0.0, y: 0.0, width: 44.0, height: 44.0)
        button.addTarget(target, action: action, for: .touchUpInside)

        let barButtonItem = UIBarButtonItem(customView: button)
        return barButtonItem
    }
}
