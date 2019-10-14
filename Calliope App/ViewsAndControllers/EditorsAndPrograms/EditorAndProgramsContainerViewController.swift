//
//  EditorAndProgramsContainerViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 07.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class EditorAndProgramsContainerViewController: UIViewController {
    
    @IBOutlet weak var editorContainerView: UIView!
    @IBOutlet weak var programContainerView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    
    @objc var editorsCollectionViewController: EditorsCollectionViewController!
    var editorsHeightConstraint: NSLayoutConstraint!
    
    @objc var programsCollectionViewController: ProgramsCollectionViewController!
    var programsHeightConstraint: NSLayoutConstraint!
    
    var editorsKvo: Any?
    var programsKvo: Any?
    var bottomInsetKvo: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        editorContainerView.translatesAutoresizingMaskIntoConstraints = false
        editorsHeightConstraint = editorContainerView.heightAnchor.constraint(equalToConstant: 10)
        editorsHeightConstraint.isActive = true
        
        programContainerView.translatesAutoresizingMaskIntoConstraints = false
        programsHeightConstraint = programContainerView.heightAnchor.constraint(equalToConstant: 10)
        programsHeightConstraint.isActive = true
    }
    
    @IBSegueAction func initializeEditor(_ coder: NSCoder) -> EditorsCollectionViewController? {
        editorsCollectionViewController = EditorsCollectionViewController(coder: coder)
        return editorsCollectionViewController
    }
    
    @IBSegueAction func initializePrograms(_ coder: NSCoder) -> ProgramsCollectionViewController? {
        programsCollectionViewController = ProgramsCollectionViewController(coder: coder)
        return programsCollectionViewController
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        editorsKvo = observe(\.editorsCollectionViewController.collectionView?.contentSize) { (containerVC, _) in
            containerVC.editorsHeightConstraint.constant = containerVC.editorsCollectionViewController.collectionView.contentSize.height
            containerVC.editorsCollectionViewController.collectionView.layoutIfNeeded()
        }
        
        programsKvo = observe(\.programsCollectionViewController.collectionView?.contentSize) { (containerVC, _) in
            containerVC.programsHeightConstraint.constant = containerVC.programsCollectionViewController.collectionView.contentSize.height
            containerVC.programsCollectionViewController.collectionView.layoutIfNeeded()
        }
    }
    
    
    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        return CGSize(width: parentSize.width - 62, height: parentSize.height)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        editorsKvo = nil
        programsKvo = nil
        bottomInsetKvo = nil
    }
}
