//
//  HomeScreenViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 13.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class HomeScreenViewController: UIViewController {

    @IBOutlet weak var homeStackView: UIStackView!
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewWillAppear(animated)
        self.rearrangeStackview(view.bounds.size)
        MatrixConnectionViewController.instance?.calliopeClass = nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (_) in
            self.rearrangeStackview(size)
        }, completion: nil)
    }
    
    private func rearrangeStackview(_ size: CGSize) {
        let landscape: Bool = size.width > size.height
        homeStackView.axis = landscape ? .horizontal : .vertical
    }
    
    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        let landscape: Bool = parentSize.width > parentSize.height
        return CGSize(width: landscape ? parentSize.width / 2.0 : parentSize.width, height: landscape ? parentSize.height : parentSize.height / 2.0)
    }
}
