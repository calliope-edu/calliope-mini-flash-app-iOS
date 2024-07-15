//
//  ProjectCollectionViewController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import UIKit
import DeepDiff
import ExternalAccessory
import CoreServices
import UniformTypeIdentifiers

class ProjectCollectionViewController: UICollectionViewController, UIDocumentPickerDelegate, UITextFieldDelegate, ProjectCellDelegate {
    private let reuseIdentifierProgram = "uploadProjectCell"

    private lazy var projects: [Project] = { () -> [Project] in
         return Project.fetchProjects()
    }()

    private var programSubscription: NSObjectProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()
        programSubscription = NotificationCenter.default.addObserver(
            forName: NotificationConstants.projectsChanged, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.animateFileChange()
                }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        animateFileChange()
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return projects.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: UICollectionViewCell
        cell = createProjectCell(collectionView, indexPath)
        return cell
    }
    
    private func createProjectCell(_ collectionView: UICollectionView, _ indexPath: IndexPath) -> UICollectionViewCell {
        let cell: ProjectCollectionViewCell
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath) as! ProjectCollectionViewCell
        cell.project = projects[indexPath.row]
        cell.delegate = self
        return cell
    }
    
    private func animateFileChange() {
        let oldItems = projects
        let newItems = Project.fetchProjects()
        let changes = diff(old: oldItems, new: newItems)
        collectionView.reload(changes: changes, section: 0, updateData: {
            self.projects = newItems
        })
    }

    // MARK: UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedItem = projects[indexPath.row]
        self.parent?.performSegue(withIdentifier: "showNewlyCreatedProject", sender: selectedItem.id)
    }
    
    func deleteProject(of cell: ProjectCollectionViewCell, project: Project) {
        guard let chartId = project.id else {
            return
        }
        Project.deleteProject(id: chartId)
        projects.removeAll { deleteChart in
            guard let deleteId = deleteChart.id else {
                return false
            }
            return deleteId == chartId
        }
        // Remove chart from UI
        guard let newIndexPath = collectionView.indexPath(for: cell) else {
            return
        }
        collectionView.deleteItems(at: [newIndexPath])
    }
    
    deinit {
        NotificationCenter.default.removeObserver(programSubscription!)
    }

}
