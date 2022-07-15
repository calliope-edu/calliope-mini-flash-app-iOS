//
//  PlaygroundStartViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.08.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

class PlaygroundStartViewController: UIViewController {

    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var snippetLibraryButton: UIButton!

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
        snippetLibraryButton.imageView?.contentMode = .scaleAspectFit
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rearrangeStackview(view.bounds.size)
        MatrixConnectionViewController.instance?.calliopeClass = FlashableCalliope.self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.rearrangeStackview(view.bounds.size)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { (_) in
            self.rearrangeStackview(size)
        }, completion: nil)
    }

    private func rearrangeStackview(_ size: CGSize) {
        let landscape: Bool = size.width > size.height
        mainStackView.axis = landscape ? .horizontal : .vertical
    }

    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        let landscape: Bool = parentSize.width > parentSize.height
        return CGSize(width: landscape ? parentSize.width / 2.0 : parentSize.width, height: landscape ? parentSize.height : parentSize.height / 2.0)
    }

}
