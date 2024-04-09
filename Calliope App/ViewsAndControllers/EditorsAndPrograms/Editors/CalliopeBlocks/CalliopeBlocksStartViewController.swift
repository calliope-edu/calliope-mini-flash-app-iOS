//
//  CalliopeBlocksStartViewController.swift
//  Calliope App
//
//  Created by itestra GmbH on 04.04.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import UIKit

class CalliopeBlocksStartViewController: UIViewController {

    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // create tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.imageTapped(gesture:)))

        // add it to the image view;
        imageView.addGestureRecognizer(tapGesture)
        // make sure imageView can be interacted with by user
        imageView.isUserInteractionEnabled = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rearrangeStackview(view.bounds.size)
        MatrixConnectionViewController.instance?.calliopeClass = DiscoveredBLEDDevice.self
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
    
    @objc func imageTapped(gesture: UIGestureRecognizer) {
        // if the tapped view is a UIImageView then set it to imageview
        if let url = URL(string: "https://apps.apple.com/de/app/scrub-web-browser/id1569777095") {
            UIApplication.shared.open(url)
        }
    }
    
    @IBAction func showGetStartedSite(_ sender: Any) {
        if let url = URL(string: "https://calliope.cc") {
            UIApplication.shared.open(url)
        }
    }
}
