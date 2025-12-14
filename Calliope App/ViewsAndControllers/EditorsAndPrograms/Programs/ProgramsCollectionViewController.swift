//
//  ProgramCollectionViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 07.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit
import DeepDiff
import ExternalAccessory
import CoreServices
import UniformTypeIdentifiers

class ProgramsCollectionViewController: UICollectionViewController, ProgramCellDelegate, UIDocumentPickerDelegate {

    private let reuseIdentifierProgram = "uploadProgramCell"

    private lazy var hexFiles: [HexFile] = { () -> [HexFile] in
        do {
            return try HexFileManager.stored()
        } catch {
            fatalError("could not load files \(error)")
        }
    }()

    private var programSubscription: NSObjectProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()
        programSubscription = NotificationCenter.default.addObserver(
            forName: NotificationConstants.hexFileChanged, object: nil, queue: nil,
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
        return hexFiles.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: UICollectionViewCell
        cell = createProgramCell(collectionView, indexPath)
        return cell
    }

    private func createProgramCell(_ collectionView: UICollectionView, _ indexPath: IndexPath) -> UICollectionViewCell {
        let cell: ProgramCollectionViewCell
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath) as! ProgramCollectionViewCell
        cell.program = hexFiles[indexPath.row]
        cell.delegate = self
        return cell
    }

    private func animateFileChange() {
        let oldItems = hexFiles
        let newItems = (try? HexFileManager.stored()) ?? []
        let changes = diff(old: oldItems as [HexFile], new: newItems as [HexFile])
        collectionView.reload(changes: changes, section: 0, updateData: {
            self.hexFiles = newItems
        })
    }

    // MARK: UICollectionViewDelegate

    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ProgramCollectionViewCell else {
            return
        }
        
        let alert = UIAlertController(title: cell.program.name, message: nil, preferredStyle: .actionSheet)
        
        let transferAction = UIAlertAction(title: NSLocalizedString("Transfer", comment: ""), style: .default) { _ in
            self.uploadProgram(of: cell)
        }
        transferAction.setValue(UIImage(systemName: "arrow.left.arrow.right"), forKey: "image")
        alert.addAction(transferAction)
        
        let shareAction = UIAlertAction(title: NSLocalizedString("Share", comment: ""), style: .default) { _ in
            cell.share()
        }
        shareAction.setValue(UIImage(systemName: "square.and.arrow.up"), forKey: "image")
        alert.addAction(shareAction)
        
        let renameAction = UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default) { _ in
            cell.edit()
        }
        renameAction.setValue(UIImage(systemName: "rectangle.and.pencil.and.ellipsis"), forKey: "image")
        alert.addAction(renameAction)
        
        let deleteAction = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in
            cell.delete()
        }
        deleteAction.setValue(UIImage(systemName: "trash"), forKey: "image")
        alert.addAction(deleteAction)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        
        alert.popoverPresentationController?.sourceView = cell
        alert.popoverPresentationController?.sourceRect = cell.bounds
        
        present(alert, animated: true)
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

    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedMenuElements -> UIMenu? in
            let actions: [UIMenuElement] = [
                UIAction(title: NSLocalizedString("Transfer", comment: ""), image: UIImage(systemName: "arrow.left.arrow.right"), handler: { (action) in
                    (
                        self.uploadProgram(of: collectionView.cellForItem(at: indexPath) as! ProgramCollectionViewCell))
                }),
                UIAction(title: NSLocalizedString("Share", comment: ""), image: UIImage(systemName: "square.and.arrow.up"), handler: { (action) in
                    (
                        self.collectionView.cellForItem(at: indexPath) as? ProgramCollectionViewCell)?.share()
                }),
                UIAction(title: NSLocalizedString("Rename", comment: ""), image: UIImage(systemName: "rectangle.and.pencil.and.ellipsis"), handler: { (action) in
                    (
                        self.collectionView.cellForItem(at: indexPath) as? ProgramCollectionViewCell)?.edit()
                }),
                UIAction(title: NSLocalizedString("Delete", comment: ""), image: UIImage(systemName: "trash"), handler: { (action) in
                    (
                        self.collectionView.cellForItem(at: indexPath) as? ProgramCollectionViewCell)?.delete(nil)
                })
            ]
            return UIMenu(title: "", children: actions)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(delete(_:)) || action == Selector(("edit")) || action == Selector(("share"))
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    }

    //dummy method for having some selector
    @objc func deleteSelectedProgram(sender: Any) {
    }

    // MARK: UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let spacing = (collectionViewLayout as! ProgramsCollectionViewFlowLayout).cellSpacing
        return UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)
    }

    // MARK: ProgramCellDelegate

    func share(cell: ProgramCollectionViewCell) {
        let program = cell.program!
        let activityItems = [/*program, program.name, program.descriptionText,*/ program.url] as [Any]

        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityViewController.modalTransitionStyle = UIModalTransitionStyle.coverVertical

        activityViewController.popoverPresentationController?.sourceRect = cell.frame
        activityViewController.popoverPresentationController?.sourceView = self.view

        self.present(activityViewController, animated: true, completion: nil)
    }

    func renameFailed(_ cell: ProgramCollectionViewCell, to newName: String) {
        let alertViewController = UIAlertController(title: String(format: NSLocalizedString("Could not rename %@", comment: ""), cell.program.name), message: String(format: NSLocalizedString("The name %@ could not be given to %@. The name for a program must be unique and not empty.", comment: ""), newName, cell.program.name), preferredStyle: .alert)
        alertViewController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            self.dismiss(animated: true, completion: nil)
        })

        alertViewController.popoverPresentationController?.sourceView = cell
        alertViewController.popoverPresentationController?.sourceRect = cell.name.frame

        self.present(alertViewController, animated: true, completion: nil)
    }

    func uploadProgram(of cell: ProgramCollectionViewCell) {
        FirmwareUpload.showUploadUI(controller: self, program: cell.program, name: cell.program.name) {
            MatrixConnectionViewController.instance.connect()
        }
    }

    func deleteProgram(of cell: ProgramCollectionViewCell) {
        let alert = UIAlertController(title: NSLocalizedString("Delete?", comment: ""), message: String(format: NSLocalizedString("Do you want to delete %@?", comment: ""), cell.program.name), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in
            do {
                try HexFileManager.delete(file: cell.program)
                self.animateFileChange()
            } catch {
                let alert = UIAlertController(title: NSLocalizedString("Delete failed", comment: ""), message: String(format: "Could not delete %@\n", cell.program.name) + error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(programSubscription!)
    }


}

