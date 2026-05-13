//
//  EditorAndProgramsContainerViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 07.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import CoreServices
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
        coordinator.animate(
            alongsideTransition: { (_) in
                self.configureLayout(size)
            },
            completion: { _ in
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

    private weak var pullScrollView: UIScrollView?

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
        scanButton?.tintColor = UIColor.white

        installPullToRefresh()
    }

    /// Mounts a UIRefreshControl on the outer scroll view of this screen so the
    /// user can pull the whole "Editoren & Programme" view downwards to re-check
    /// for new hex files (e.g. ones just dropped into the iCloud folder from the
    /// Files app). The inner programs collection view doesn't scroll on its own
    /// — its height is KVO-bound to its content — so the refresh control has to
    /// live on the outer scroll view, not on the collection view.
    private func installPullToRefresh() {
        guard let scrollView = findOuterScrollView(in: view) else {
            LogNotify.log("Pull-to-refresh: no outer scroll view found")
            return
        }
        pullScrollView = scrollView
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handlePullToRefresh(_:)), for: .valueChanged)
        scrollView.refreshControl = refresh
        scrollView.alwaysBounceVertical = true
    }

    private func findOuterScrollView(in root: UIView) -> UIScrollView? {
        if let sv = root as? UIScrollView { return sv }
        for sub in root.subviews {
            if let found = findOuterScrollView(in: sub) { return found }
        }
        return nil
    }

    @objc private func handlePullToRefresh(_ sender: UIRefreshControl) {
        // Minimum spinner duration so the gesture always feels like it did
        // something — even when no new files are present. The actual diff
        // happens at the end of the wait so the batch update doesn't yank the
        // refresh control off-screen prematurely.
        let minimumSpinnerDuration: TimeInterval = 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumSpinnerDuration) { [weak self] in
            self?.programsCollectionViewController?.refreshFromExternalChanges()
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        }
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

        MatrixConnectionViewController.instance?.connectionDescriptionText = NSLocalizedString("Calliope mini verbinden!", comment: "")
        MatrixConnectionViewController.instance?.calliopeClass = DiscoveredBLEDevice.self
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
        let program = DefaultProgram(programName: NSLocalizedString("Calliope mini V3", comment: ""), url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV3Url.rawValue)!)
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }

    @IBAction func uploadDefaultV2And1Program(_sender: Any) {
        let program = DefaultProgram(programName: NSLocalizedString("Calliope mini V1 + 2", comment: ""), url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue)!)
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }

    @IBAction func navigateToImportFile() {
        let types: [UTType] = getFileTypesFor(fileEnding: "hex")

        DispatchQueue.main.async {
            let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: types)
            documentPickerController.delegate = self
            self.present(documentPickerController, animated: true, completion: nil)
        }
    }

    func getFileTypesFor(fileEnding: String) -> [UTType] {
        if let utType = UTType(filenameExtension: fileEnding) {
            return [utType]
        }
        return []
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentAt url: URL
    ) {
        if !(url.lastPathComponent.isEmpty) {
            // Dismiss this view
            dismiss(animated: true, completion: nil)
            HexFileStoreDialog.showStoreHexUI(controller: self, hexFile: url, notSaved: { _ in })
        }
    }
}
