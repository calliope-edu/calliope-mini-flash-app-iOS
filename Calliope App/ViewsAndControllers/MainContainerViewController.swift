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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateTraitOverrides()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatrixConnectionViewModel.instance.viewController = self // TODO: Remove after SwiftUI migration
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        updateTraitOverrides()
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
