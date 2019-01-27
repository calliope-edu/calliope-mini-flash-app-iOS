import UIKit

extension UIImage {

    func imageTinted(_ color: UIColor) -> UIImage {
        let template = self.withRenderingMode(.alwaysTemplate)
        let view = UIImageView(image: template)
        view.tintColor = color

        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0.0)
        if let context = UIGraphicsGetCurrentContext() {
            view.layer.render(in: context)
            let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return tintedImage!
        } else {
            fatalError()
        }
    }
}
