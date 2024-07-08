//
//  ProjectOverviewController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import UIKit
import CoreServices
import SwiftUI

class ProjectOverviewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    
    @IBOutlet weak var stackView: UIStackView?
    @IBOutlet weak var addProjectButton: UIButton!
    @IBOutlet weak var projectContainerView: UIView?
    
    @objc var projectCollectionViewController: ProjectCollectionViewController?
    
    var projectHeightConstraint: NSLayoutConstraint?
    var projectKvo: Any?
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (_) in
            self.configureLayout(size)
        }, completion: { _ in
            self.projectCollectionViewController?.collectionView.reloadData()
        })
    }
    
    private func configureLayout(_ size: CGSize) {
        let landscape = size.width > size.height
        stackView?.distribution = landscape ? .fillEqually : .fill
        stackView?.alignment = landscape ? .top : .fill
        stackView?.axis = landscape ? .horizontal : .vertical
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addProjectButton.setTitle("", for: .normal)
        projectContainerView?.translatesAutoresizingMaskIntoConstraints = false
        projectHeightConstraint = projectContainerView?.heightAnchor.constraint(equalToConstant: 10)
        projectHeightConstraint?.isActive = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        projectKvo = observe(\.projectCollectionViewController?.collectionView.contentSize) { (containerVC, _) in
            containerVC.projectHeightConstraint!.constant = containerVC.projectCollectionViewController!.collectionView.contentSize.height
            containerVC.projectCollectionViewController?.collectionView.layoutIfNeeded()
        }
        
        MatrixConnectionViewController.instance?.connectionDescriptionText = NSLocalizedString("Calliope mini verbinden", comment: "")
        MatrixConnectionViewController.instance?.calliopeClass = DiscoveredBLEDDevice.self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        projectKvo = nil
    }
    
    @IBSegueAction func initializeProjects(_ coder: NSCoder) -> ProjectCollectionViewController? {
        print("setting project collection view controller")
        projectCollectionViewController = ProjectCollectionViewController(coder: coder)
        self.reloadInputViews()
        return projectCollectionViewController
    }
    
    @IBAction func createNewProject(_ coder: NSCoder) {
        LogNotify.log("Starting to create a new Project")
        let alertController = UIAlertController(title: NSLocalizedString("Enter an Projectname for the new Project", comment: ""), message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Calliope Project"
        }

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let name = textField.text {
                let normalizedName = name.isEmpty ? "Calliope Project" : name
                let project = Project.insertProject(name: normalizedName)
                self.performSegue(withIdentifier: "showNewlyCreatedProject", sender: project?.id)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showNewlyCreatedProject" {
            print("Preparing for segue showNewlyCreatedProject")
            guard let destinationVC = segue.destination as? ProjectViewController else {
                return
            }
            destinationVC.project = Project.fetchProject(id: sender as! Int)!
        }
    }
}
