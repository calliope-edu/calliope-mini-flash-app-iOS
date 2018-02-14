import UIKit

//extension UIViewController {
//    class func loadFromNib<T: UIViewController>() -> T {
//         return T(nibName: String(describing: self), bundle: nil)
//    }
//}

//extension UIViewController {
//
////    func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
////        super.willTransition(to: newCollection, with: coordinator)
////
////        LOG("viewWillTransition to trait \(newCollection)")
////
////        coordinator.animate(alongsideTransition: { _ in
////            self.updateConstraintsForTraitCollection(newCollection)
////            self.view.setNeedsLayout()
////        }, completion: nil)
////    }
//
//
//    func updateConstraintsForTraitCollection(_ collection: UITraitCollection) {
//
//        let size = view.bounds.size
//
//        LOG("updating contraints \(size)")
//
//        let wide = size.width >= size.height
//        if wide {
//            LOG("HORI")
//        } else {
//            LOG("VERT")
//        }
//
////        var newConstraints = [NSLayoutConstraint]()
////        if collection.verticalSizeClass == .compact {
////        }
////        else {
////        }
////        NSLayoutConstraint.deactivate(constraints)
////        constraints = newConstraints
////        NSLayoutConstraint.activate(newConstraints)
//    }
//
//}
