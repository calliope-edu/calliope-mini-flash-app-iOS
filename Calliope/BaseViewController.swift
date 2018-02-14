import UIKit

class BaseViewController: UIViewController {

    func createCancelButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("button.cancel".localized, for: .normal)
        button.titleLabel?.font = Styles.defaultFont(size: range(15...25))
        //button.setImage(UIImage.loadImage(named: "Device"), for: .normal)
        //button.imageView?.contentMode = .scaleAspectFit
        //button.imageEdgeInsets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 5.0)
        button.sizeToFit()
        return button
    }

    func createHelpButton() -> UIButton {
        let margin = CGFloat(10)
        let spacing = CGFloat(0)

        //let image = UIImage.loadImage(named: "IconHelp")
        let image = UIImage.imageWithPDFNamed("IconHelp", size: CGSize(width: 40, height:40))
        let button = UIButton(type: .system)
        button.setTitle("button.help".localized, for: .normal)
        button.titleLabel?.font = Styles.defaultFont(size: range(15...25))
        button.setImage(image, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit

        button.imageEdgeInsets = UIEdgeInsets(
            top: margin,
            left: -spacing,
            bottom: margin,
            right: spacing)
        button.titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: spacing,
            bottom: 0,
            right: -spacing)
        button.contentEdgeInsets = UIEdgeInsets(
            top: 0,
            left: spacing,
            bottom: 0,
            right: spacing)

        button.sizeToFit()
        button.addAction(for: .touchUpInside, actionHelp)
        return button
    }

    func actionHelp(_ button: UIButton) {
        let vc = HelpViewController()
        vc.html = ("_" + self.className).localized
        if let navigationController = self.navigationController {
            navigationController.pushViewController(vc, animated: true)
        }
    }

//    @objc func backButtonAction() {
//        dismiss(animated: true, completion: nil)
//    }
//
//    func setBackButton(title: String) {
//        if let nav = self.navigationController, let item = nav.navigationBar.topItem {
//            item.backBarButtonItem = UIBarButtonItem(
//                title: title,
//                style: .plain,
//                target: self, action:
//                #selector(self.backButtonAction))
//        }
//    }

}
