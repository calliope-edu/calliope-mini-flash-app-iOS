//
//  ArcadeStartViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.08.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

class ArcadeStartViewController: UIViewController {

    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var openArcadeButton: UIButton!
    @IBOutlet weak var screenshotImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if UIDevice.current.userInterfaceIdiom == .phone {
                screenshotImageView.isHidden = true
            }
        // Titel setzen
        navigationItem.title = NSLocalizedString("Arcade (mit USB)", comment: "Arcade (USB only)")
        
        // Button-Text setzen
        openArcadeButton.setTitle(NSLocalizedString("Los geht's!", comment: "Let's go!"), for: .normal)
        
        // Button Font fetter machen
        openArcadeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        
        // Button Textfarbe weiß (auch beim Drücken)
        openArcadeButton.setTitleColor(.white, for: .normal)
        openArcadeButton.setTitleColor(.white, for: .highlighted)
        
        // Button Hintergrundfarbe
        openArcadeButton.backgroundColor = UIColor.systemPink
        
        // Button abgerundete Ecken
        openArcadeButton.layer.cornerRadius = 10
        openArcadeButton.clipsToBounds = true
        
        // Button breiter machen (Padding innen)
        openArcadeButton.contentEdgeInsets = UIEdgeInsets(top: 20, left: 60, bottom: 20, right: 60)
        openArcadeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        openArcadeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 230).isActive = true
        
        // Button Action verbinden
        openArcadeButton.addTarget(self, action: #selector(openArcadeButtonTapped(_:)), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rearrangeStackview(view.bounds.size)
        // MatrixConnectionViewController.instance?.calliopeClass = DiscoveredBLEDDevice.self
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
    
    @objc @IBAction func openArcadeButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "EditorAndPrograms", bundle: nil)
        if let editorVC = storyboard.instantiateViewController(withIdentifier: "EditorViewController") as? EditorViewController {
            editorVC.editor = ArcadeEditor()
            navigationController?.pushViewController(editorVC, animated: true)
        }
    }
}
