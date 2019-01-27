//
//  CancelButtonProtocol.swift
//  Calliope
//
//  Created by Benedikt Spohr on 1/27/19.
//

import UIKit

/// Protocol to add the cancel button to every vieController.
///
/// Call addCancelButton in viewDidLoad to add cancel button
protocol CancelButtonProtocol {
    func addCancelButton(pressed: @escaping (() -> Void))
}

extension UIViewController: CancelButtonProtocol {

    /// Adds a cancel button
    ///
    /// Will be add as barButtonItem on the left side.
    /// Needs a navigationController.
    /// - Parameter pressed: Called if button get pressed
    func addCancelButton(pressed: @escaping (() -> Void)) {
        let button = UIButton(type: .system)
        button.setTitle("button.cancel".localized, for: .normal)
        button.titleLabel?.font = Styles.defaultFont(size: range(15...25))
        button.sizeToFit()
        button.addAction(for: .primaryActionTriggered) { _ in
            pressed()
        }
        
        if navigationItem.rightBarButtonItem == nil  {
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
        } else {
            navigationItem.leftBarButtonItems?.append(UIBarButtonItem(customView: button))
        }
    }
}



