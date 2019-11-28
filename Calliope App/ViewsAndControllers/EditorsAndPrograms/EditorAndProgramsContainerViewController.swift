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
        
        MatrixConnectionViewController.instance?.connectionDescriptionText = "ConnectionDescription for program upload"
        MatrixConnectionViewController.instance?.changeCalliopeType(sender: self, calliopeClass: DFUCalliope.self)
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
        if (program.bin.count != 0) {
            FirmwareUpload.showUploadUI(controller: self, program: program) {
                MatrixConnectionViewController.instance.connect()
            }
        } else {
            let alertStart = UIAlertController(title: "Wait a little", message: "The program is being downloaded. Please wait a little.", preferredStyle: .alert)
            alertStart.addAction(UIAlertAction(title: "Ok", style: .default))
            
            self.present(alertStart, animated: true) {
                program.load { error in
                    let alert: UIAlertController
                    
                    if error == nil {
                        let alertDone = UIAlertController(title: "Download finished", message: "The program is downloaded. Do you want to upload it now?", preferredStyle: .alert)
                        alertDone.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
                            self.uploadDefaultProgram(self)
                        })
                        alertDone.addAction(UIAlertAction(title: "No", style: .cancel))
                        alert = alertDone
                    } else {
                        let alertError = UIAlertController(title: "Program download failed", message: "The program is not ready. The reason is\n\(error!.localizedDescription)", preferredStyle: .alert)
                        alertError.addAction(UIAlertAction(title: "Ok", style: .default))
                        alert = alertError
                    }
                    DispatchQueue.main.async {
                        alertStart.dismiss(animated: true) {
                            self.present(alert, animated: true)
                        }
                    }
                }
            }
        }
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
