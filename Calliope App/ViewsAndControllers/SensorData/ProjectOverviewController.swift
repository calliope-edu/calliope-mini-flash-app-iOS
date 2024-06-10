//
//  SensorRecordingsController.swift
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
        
        projectContainerView?.translatesAutoresizingMaskIntoConstraints = false
        projectHeightConstraint = projectContainerView?.heightAnchor.constraint(equalToConstant: 10)
        projectHeightConstraint?.isActive = true
        
        configureLayout(UIApplication.shared.keyWindow!.frame.size)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        projectKvo = observe(\.projectCollectionViewController?.collectionView.contentSize) { (containerVC, _) in
            containerVC.projectHeightConstraint!.constant = containerVC.projectCollectionViewController!.collectionView.contentSize.height
            containerVC.projectCollectionViewController?.collectionView.layoutIfNeeded()
        }
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
    
    static var number: Int = 0
    
    @IBSegueAction func createNewProject(_ coder: NSCoder) -> ProjectViewController? {
        let project: Project = try Project.insertProject(name: "NewProject" + String(ProjectOverviewController.number))!
        (ProjectOverviewController.number+=1)
        projectCollectionViewController?.reloadInputViews()
        return ProjectViewController(coder: coder, project: project)
    }
    
    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        return CGSize(width: parentSize.width - 62, height: parentSize.height)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //we use segue initialization for ios13.
        // When ios11 compatibility is dropped, this method can be deleted.
        if #available(iOS 13.0, *) { return }
        
        if segue.identifier == "embedPrograms" {
            projectCollectionViewController = segue.destination as? ProjectCollectionViewController
        }
    }
    
    
    
}
