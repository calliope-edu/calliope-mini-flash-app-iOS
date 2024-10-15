//
//  MainContainerViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 02.06.19.
//

import UIKit
import SnapKit

class MainContainerViewController: UITabBarController, UITabBarControllerDelegate {

    @IBOutlet weak var matrixConnectionView: UIView!

    weak var connectionViewController: MatrixConnectionViewController!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateTraitOverrides()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.async {
            //called on the non-concurrent main queue so no further synchronization necessary
            self.addConnectionViewController()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        updateTraitOverrides()
    }

    func addConnectionViewController() {
        guard connectionViewController == nil else {
            return
        }

        let window = (UIApplication.shared.delegate!.window!)!

        DispatchQueue.main.async {
            let connectionVC = UIStoryboard(name: "ConnectionView", bundle: nil).instantiateInitialViewController() as! MatrixConnectionViewController
            connectionVC.view.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(connectionVC.view)

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
