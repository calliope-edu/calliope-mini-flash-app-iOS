//
//  MainContainerViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 02.06.19.
//

import UIKit
import SnapKit

class MainContainerViewController: UIViewController {

    @IBOutlet weak var matrixConnectionView: UIView!

    weak var connectionViewController: MatrixConnectionViewController!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateTraitOverrides()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.addConnectionViewController()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        updateTraitOverrides()
    }

    func addConnectionViewController() {
        guard connectionViewController == nil else {
            return
        }

        // Under the scene life cycle the window belongs to the scene, so
        // `UIApplication.shared.delegate.window` is nil — force-unwrapping it
        // crashed here. This runs from `viewDidAppear`, so the controller is in
        // a window; should it ever not be, the next appearance retries.
        guard let window = view.window else {
            LogNotify.log("No window yet - connection view is attached on the next appearance")
            return
        }   

        DispatchQueue.main.async {
            let connectionVC = UIStoryboard(name: "ConnectionView", bundle: nil).instantiateInitialViewController() as! MatrixConnectionViewController
            connectionVC.view.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(connectionVC.view)
            self.addChild(connectionVC)
            NSLayoutConstraint.activate([
                                            connectionVC.view.rightAnchor.constraint(equalTo: window.safeAreaLayoutGuide.rightAnchor, constant: -8.0),
                                            connectionVC.view.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8.0),
                                            connectionVC.view.leftAnchor.constraint(greaterThanOrEqualTo: window.safeAreaLayoutGuide.leftAnchor, constant: 0.0),
                                            connectionVC.view.bottomAnchor.constraint(lessThanOrEqualTo: window.safeAreaLayoutGuide.bottomAnchor, constant: 0.0)
                                        ])

            connectionVC.didMove(toParent: self)
            self.connectionViewController = connectionVC
        }
    }

    private func updateTraitOverrides() {
        guard #available(iOS 18.0, *)
        else {
            return
        }

        // Update the current size class to display original design
        traitOverrides.horizontalSizeClass = .compact
    }
}
