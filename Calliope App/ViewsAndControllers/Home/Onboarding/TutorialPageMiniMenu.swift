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
    var navigationExplanation: MenuNavigationCollectionViewController! {
        didSet {
            navigationExplanation.view.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    @IBOutlet weak var itemsExplanationView: UIView!
    var itemsExplanation: MenuItemsCollectionViewController! {
        didSet {
            itemsExplanation.view.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationExplanation.view.topAnchor.constraint(equalTo: navigationExplanationView.topAnchor).isActive = true
        navigationExplanation.view.bottomAnchor.constraint(equalTo: navigationExplanationView.bottomAnchor).isActive = true
        navigationExplanation.view.leftAnchor.constraint(equalTo: navigationExplanationView.leftAnchor).isActive = true
        navigationExplanation.view.rightAnchor.constraint(equalTo: navigationExplanationView.rightAnchor).isActive = true
        
        itemsExplanation.view.topAnchor.constraint(equalTo: itemsExplanationView.topAnchor).isActive = true
        itemsExplanation.view.bottomAnchor.constraint(equalTo: itemsExplanationView.bottomAnchor).isActive = true
        itemsExplanation.view.leftAnchor.constraint(equalTo: itemsExplanationView.leftAnchor).isActive = true
        itemsExplanation.view.rightAnchor.constraint(equalTo: itemsExplanationView.rightAnchor).isActive = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationExplanation.finishedCallback = { [weak self] in self?.animateItems() }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationExplanation.animate()
    }
    
    func animateItems() {
        itemsExplanation.animate()
    }
    
    @IBSegueAction func initializeNavigationExplanation(_ coder: NSCoder) -> MenuNavigationCollectionViewController? {
        navigationExplanation = MenuNavigationCollectionViewController(coder: coder)
        return navigationExplanation
    }
    
    @IBSegueAction func initializeItemExplanation(_ coder: NSCoder) -> MenuItemsCollectionViewController? {
        itemsExplanation = MenuItemsCollectionViewController(coder: coder)
        return itemsExplanation
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if #available(iOS 13.0, *) { return }
        
        if segue.identifier == "embedMenuNavigationCollectionController" {
            self.navigationExplanation = segue.destination as? MenuNavigationCollectionViewController
        } else if segue.identifier == "embedMenuItemsCollectionController" {
            self.itemsExplanation = segue.destination as? MenuItemsCollectionViewController
        }
    }
}
