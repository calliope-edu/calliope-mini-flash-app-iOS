//
//  ProjectController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import DGCharts

class ProjectViewController: UIViewController, ChartViewDelegate, UIContextMenuInteractionDelegate {
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let action1 = UIAction(title: "Action 1", image: UIImage(systemName: "star")) { action in
                // Handle action 1
                print("Action 1 selected")
            }
            let action2 = UIAction(title: "Action 2", image: UIImage(systemName: "heart")) { action in
                // Handle action 2
                print("Action 2 selected")
            }
            return UIMenu(title: "", children: [action1, action2])
        }
    }
    
    var project: Project?
    var projectId: Int?
    
    @IBOutlet weak var chartsContainerView: UIView?
    @IBOutlet weak var projectNameLabel: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    
    @objc var chartCollectionViewController: ChartCollectionViewController?
    var chartHeightConstraint: NSLayoutConstraint?
    var chartsKvo: Any?
    
    init?(coder: NSCoder, project: Project) {
        self.project = project
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        projectNameLabel.text = project?.name
        
        chartsContainerView?.translatesAutoresizingMaskIntoConstraints = false
        chartHeightConstraint = chartsContainerView?.heightAnchor.constraint(equalToConstant: 10)
        chartHeightConstraint?.isActive = true
        
        chartCollectionViewController?.project = project
        
        let interaction = UIContextMenuInteraction(delegate: self)
        settingsButton.addInteraction(interaction)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        chartsKvo = observe(\.chartCollectionViewController?.collectionView.contentSize) { (containerVC, _) in
            UIView.animate(withDuration: 1.0) {
                containerVC.chartHeightConstraint!.constant = containerVC.chartCollectionViewController!.collectionView.contentSize.height
                containerVC.chartCollectionViewController?.collectionView.layoutIfNeeded()
                self.view.layoutIfNeeded()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        chartsKvo = nil
    }
    
    @IBSegueAction func initializeCharts(_ coder: NSCoder) -> ChartCollectionViewController? {
        chartCollectionViewController = ChartCollectionViewController(coder: coder)
        self.reloadInputViews()
        return chartCollectionViewController
    }
    
    @IBAction func recordNewSensor() {
        chartCollectionViewController?.addChart()
    }
    
    @IBAction func renameProject() {
        let alertController = UIAlertController(title: "Change project name", message: "Enter the new project name", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "New project name"
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let inputText = textField.text {
                self.project?.name = inputText
                self.projectNameLabel.text = inputText
                if let project = self.project {
                    Project.updateProject(project: project)
                    NotificationCenter.default.post(name: NotificationConstants.projectsChanged, object: self)
                }
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func deleteProject() {
        Project.deleteProject(id: project?.id)
        NotificationCenter.default.post(name: NotificationConstants.projectsChanged, object: self)
        dismiss(animated: true, completion: nil)
        navigationController?.popViewController(animated: true)
    }
}
