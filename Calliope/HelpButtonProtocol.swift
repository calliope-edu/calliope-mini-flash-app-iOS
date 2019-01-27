//
//  HelpButtonProtocol.swift
//  Calliope
//
//  Created by Benedikt Spohr on 1/27/19.
//

import UIKit


/// Protocol to add the help button to every vieController.
///
/// Call addHelpButton in viewDidLoad to add help button
protocol HelpButtonProtocol {
    func addHelpButton()
}

extension UIViewController: HelpButtonProtocol {
    
    /// Adds a help button
    ///
    /// Will be add as barButtonItem on the right side.
    /// Needs a navigationController.
    func addHelpButton() {
        let margin = CGFloat(10)
        let spacing = CGFloat(0)
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
        button.addAction(for: .primaryActionTriggered) { [weak self] _ in
            self?.showHelpViewController()
        }
        if navigationItem.rightBarButtonItem == nil  {
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
        } else {
            navigationItem.rightBarButtonItems?.append( UIBarButtonItem(customView: button))
        }
    }

    
    private func showHelpViewController() {
        let vc = HelpViewController()
        vc.html = ("_" + self.className).localized
        if let navigationController = self.navigationController {
            navigationController.pushViewController(vc, animated: true)
        }
    }
}
