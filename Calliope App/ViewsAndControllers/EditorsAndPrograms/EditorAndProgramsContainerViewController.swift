//
//  EditorAndProgramsContainerViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 07.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class EditorAndProgramsContainerViewController: UIViewController {
    
    @IBOutlet weak var stackView: UIStackView?
    
    @IBOutlet weak var editorContainerView: UIView?
    
    @IBOutlet weak var programContainerView: UIView?
    
    @objc var editorsCollectionViewController: EditorsCollectionViewController?
    @IBOutlet var editorTopToSafeArea: NSLayoutConstraint?
    @IBOutlet var editorBottomToSafeArea: NSLayoutConstraint?
    var editorsHeightConstraint: NSLayoutConstraint?
    
    @objc var programsCollectionViewController: ProgramsCollectionViewController?
    var programsHeightConstraint: NSLayoutConstraint?
    
    var editorsKvo: Any?
    var programsKvo: Any?
    var bottomInsetKvo: Any?
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (_) in
            self.configureLayout(size)
        }, completion: { _ in
            self.programsCollectionViewController?.collectionView.reloadData()
            self.editorsCollectionViewController?.collectionView.reloadData()
        })
    }
    
    private func configureLayout(_ size: CGSize) {
        let landscape = size.width > size.height
        stackView?.distribution = landscape ? .fillEqually : .fill
        stackView?.alignment = landscape ? .top : .fill
        stackView?.axis = landscape ? .horizontal : .vertical
        editorTopToSafeArea?.isActive = landscape
        editorBottomToSafeArea?.isActive = landscape
    }
    
    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
        
        editorContainerView?.translatesAutoresizingMaskIntoConstraints = false
        editorsHeightConstraint = editorContainerView?.heightAnchor.constraint(equalToConstant: 10)
        editorsHeightConstraint?.isActive = true
        
        programContainerView?.translatesAutoresizingMaskIntoConstraints = false
        programsHeightConstraint = programContainerView?.heightAnchor.constraint(equalToConstant: 10)
        programsHeightConstraint?.isActive = true
        
        configureLayout(UIApplication.shared.keyWindow!.frame.size)
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
        
        editorsKvo = observe(\.editorsCollectionViewController?.collectionView.contentSize) { (containerVC, _) in
            containerVC.editorsHeightConstraint!.constant = containerVC.editorsCollectionViewController!.collectionView.contentSize.height
            containerVC.editorsCollectionViewController?.collectionView.layoutIfNeeded()
        }
        
        programsKvo = observe(\.programsCollectionViewController?.collectionView.contentSize) { (containerVC, _) in
            containerVC.programsHeightConstraint!.constant = containerVC.programsCollectionViewController!.collectionView.contentSize.height
            containerVC.programsCollectionViewController?.collectionView.layoutIfNeeded()
        }
        
        MatrixConnectionViewController.instance?.connectionDescriptionText = NSLocalizedString("Connect to enable uploading programs", comment: "")
        MatrixConnectionViewController.instance?.calliopeClass = FlashableCalliope.self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        editorsKvo = nil
        programsKvo = nil
        bottomInsetKvo = nil
    }
    
    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        return CGSize(width: parentSize.width - 62, height: parentSize.height)
    }
    
    @IBAction func uploadDefaultProgram(_ sender: Any) {
        let program = DefaultProgram.defaultProgram
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //we use segue initialization for ios13.
        // When ios11 compatibility is dropped, this method can be deleted.
        if #available(iOS 13.0, *) { return }
        
        if segue.identifier == "embedEditors" {
            editorsCollectionViewController = segue.destination as? EditorsCollectionViewController
        } else if segue.identifier == "embedPrograms" {
            programsCollectionViewController = segue.destination as? ProgramsCollectionViewController
        }
    }
}
