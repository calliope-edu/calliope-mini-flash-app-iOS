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

class ProjectCollectionViewController: UICollectionViewController, ProjectCellDelegate, UIDocumentPickerDelegate {

    private let reuseIdentifierProgram = "uploadProjectCell"

    private lazy var projects: [Project] = { () -> [Project] in
        do { return try Project.fetchProjects() }
        catch { fatalError("could not load files \(error)") }
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
        
        //TODO: Configure the cell
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath) as! ProjectCollectionViewCell

        cell.project = projects[indexPath.row]
        cell.delegate = self
        
        return cell
    }
    
    private func animateFileChange() {
        let oldItems = projects
        let newItems = (try? Project.fetchProjects()) ?? []
        let changes = diff(old: oldItems, new: newItems)
        collectionView.reload(changes: changes, section: 0, updateData: {
            self.projects = newItems
        })
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedItem = projects[indexPath.row]
        performSegue(withIdentifier: "showProjectSegue", sender: selectedItem.id)
    }

    @IBSegueAction func initializeProject(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> ProjectViewController? {
        print("Opening project \(sender as! Int)")
        let projectController = ProjectViewController(coder: coder, project: Project.fetchProject(id: sender as! Int)!)
        return projectController
    }
    
    // menu

    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: NSLocalizedString("Edit", comment: ""), action: Selector(("edit"))),
            UIMenuItem(title: NSLocalizedString("Share", comment: ""), action: Selector(("share")))
        ]
        return true
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(delete(_:)) || action == Selector(("edit")) || action == Selector(("share"))
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
        print("press")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetailSegue" {
            if let detailVC = segue.destination as? ProjectViewController, let selectedItem = sender as? Int {
                detailVC.projectId = selectedItem
            }
        }
    }

    //dummy method for having some selector
    @objc func deleteSelectedProgram(sender: Any) {}

    // MARK: UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let spacing = (collectionViewLayout as! ProgramsCollectionViewFlowLayout).cellSpacing
        return UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)
    }

    // MARK: ProjectCellDelegate
    func share(cell: ProjectCollectionViewCell) {
        print("TODO")
    }
    
    func renameFailed(_ cell: ProjectCollectionViewCell, to newName: String) {
        print("TODO")
    }
    
    func uploadProgram(of cell: ProjectCollectionViewCell) {
        print("TODO")
    }
    
    func deleteProgram(of cell: ProjectCollectionViewCell) {
        print("TODO")
    }
    
    

    deinit {
        NotificationCenter.default.removeObserver(programSubscription!)
    }

}
