//
//  TutorialPageMiniMenu.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.12.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageMiniMenu: TutorialPageViewController {
    
    @IBOutlet weak var navigationExplanationView: UIView!
    var navigationExplanation: TutorialPageMiniMenuNavigationCollectionViewController!
    
    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()

        navigationExplanation.view.translatesAutoresizingMaskIntoConstraints = false
        
        navigationExplanation.view.topAnchor.constraint(equalTo: navigationExplanationView.topAnchor).isActive = true
        navigationExplanation.view.bottomAnchor.constraint(equalTo: navigationExplanationView.bottomAnchor).isActive = true
        navigationExplanation.view.leftAnchor.constraint(equalTo: navigationExplanationView.leftAnchor).isActive = true
        navigationExplanation.view.rightAnchor.constraint(equalTo: navigationExplanationView.rightAnchor).isActive = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationExplanation.animate()
    }
    
    @IBSegueAction func initializeNavigationExplanation(_ coder: NSCoder) -> TutorialPageMiniMenuNavigationCollectionViewController? {
        navigationExplanation = TutorialPageMiniMenuNavigationCollectionViewController(coder: coder)
        return navigationExplanation
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if #available(iOS 13.0, *) { return }
        
        if segue.identifier == "embedMenuNavigationCollectionController" {
            self.navigationExplanation = segue.destination as? TutorialPageMiniMenuNavigationCollectionViewController
        }
    }
}
