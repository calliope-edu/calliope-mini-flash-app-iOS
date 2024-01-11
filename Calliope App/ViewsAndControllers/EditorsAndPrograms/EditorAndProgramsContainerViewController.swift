//
//  EditorAndProgramsContainerViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 07.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit
import CoreServices

class EditorAndProgramsContainerViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    
    @IBOutlet weak var stackView: UIStackView?
    
    @IBOutlet weak var editorContainerView: UIView?
    
    @IBOutlet weak var programContainerView: UIView?
    
    @IBOutlet weak var scanButton: UIButton?
    
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
        super.viewDidLoad()
        
        editorContainerView?.translatesAutoresizingMaskIntoConstraints = false
        editorsHeightConstraint = editorContainerView?.heightAnchor.constraint(equalToConstant: 10)
        editorsHeightConstraint?.isActive = true
        
        programContainerView?.translatesAutoresizingMaskIntoConstraints = false
        programsHeightConstraint = programContainerView?.heightAnchor.constraint(equalToConstant: 10)
        programsHeightConstraint?.isActive = true
        
        configureLayout(UIApplication.shared.keyWindow!.frame.size)
        scanButton?.imageView?.contentMode = UIView.ContentMode.scaleAspectFit
        scanButton?.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
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
        MatrixConnectionViewController.instance?.calliopeClass = DiscoveredBLEDDevice.self
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
    
    @IBAction func uploadDefaultV3Program(_ sender: Any) {
        let program = DefaultProgram(programName: NSLocalizedString("Calliope mini V3", comment:""), url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV3Url.rawValue)!)
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }
    
    @IBAction func uploadDefaultV2And1Program(_sender: Any) {
        let program = DefaultProgram(programName: NSLocalizedString("Calliope mini V1 + 2", comment:""), url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue)!)
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }
    
    @IBAction func openChangeDirectoryView() {
        let folderPickerController = UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String],
                                           in: .open)
        folderPickerController.delegate = self
        self.present(folderPickerController, animated: true, completion: nil)
    }
    
    @IBAction func navigateToImportFile() {
        var types: [String] = [String]()
        types.append("com.intel.hex")
        
        let documentPickerController = UIDocumentPickerViewController(documentTypes: types, in: .import)
        documentPickerController.delegate = self
        present(documentPickerController, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
              didPickDocumentAt url: URL) {
        if !(url.lastPathComponent.isEmpty) {
            // Dismiss this view
            dismiss(animated: true, completion: nil)

            let alertStart = UIAlertController(title: NSLocalizedString("Öffnen", comment: ""), message: NSLocalizedString("Möchtest du die Datei in MakeCode öffnen oder direkt auf deinen Calliope mini übertragen?", comment: ""), preferredStyle: .alert)
            alertStart.addAction(UIAlertAction(title: NSLocalizedString("Öffnen", comment: ""), style: .default) { _ in
                // TODO: Needs to open MakeCode instead
                self.uploadFile(url: url)
            })
            alertStart.addAction(UIAlertAction(title: NSLocalizedString("Übertragen", comment: ""), style: .default) { _ in
                self.uploadFile(url: url)
            })
            alertStart.addAction(UIAlertAction(title: NSLocalizedString("Schließen", comment: ""), style: .cancel) )
            present(alertStart, animated: true)
        }
    }
    
    func uploadFile(url: URL) {
        if (try? Data(contentsOf: url)) != nil {
            if let fileName: String = url.lastPathComponent.components(separatedBy: ".").first {
                let program = DefaultProgram(programName: NSLocalizedString(fileName, comment:""), url: url.standardizedFileURL.absoluteString)
                program.downloadFile = false
                FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
            } else {
                LogNotify.log("Failed loading File")
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
