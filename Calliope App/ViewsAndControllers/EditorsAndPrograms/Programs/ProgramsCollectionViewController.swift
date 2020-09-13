//
//  ProgramCollectionViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 07.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit
import DeepDiff

class ProgramsCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, ProgramCellDelegate {

    private let reuseIdentifierProgram = "uploadProgramCell"

    private lazy var hexFiles: [HexFile] = { () -> [HexFile] in
        do { return try HexFileManager.stored() }
        catch { fatalError("could not load files \(error)") }
    }()
    
    private var viewSize: CGSize?

    private var programSubscription: NSObjectProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()
        (collectionViewLayout as! UICollectionViewFlowLayout).estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        programSubscription = NotificationCenter.default.addObserver(
            forName: NotificationConstants.hexFileChanged, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.animateFileChange()
                }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewSize = collectionView.frame.size
        //collectionView.performBatchUpdates({}, completion: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        viewSize = size
        
        //recalculateSizeOfAllCells(size) //commented out for uploadProgramCell only! comment in when other cell is used
        
        coordinator.animate(alongsideTransition: {_ in
            self.collectionView.performBatchUpdates(nil, completion: nil)
        }, completion: nil)
    }
    
    private func recalculateSizeOfAllCells(_ size: CGSize) {
        let cells = self.collectionView.visibleCells.compactMap { $0 as? ProgramCollectionViewCell }
        for cell in cells {
            self.recalculateProgramCellSize(size, cell)
        }
    }
    
    private func recalculateProgramCellSize(_ size: CGSize, _ cell: ProgramCollectionViewCell) {
        let width = size.width - spacing
        let maxNumCells = ceil(width / programWidthThreshold)
        let calculatedWidth = width / maxNumCells - spacing
        cell.widthConstraint.constant = calculatedWidth
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
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        //for uploadProgramCell only! delete method when other cell is used
        return CGSize(width: collectionView.frame.size.width - 20, height: 70)
    }
    
    private func createProgramCell(_ collectionView: UICollectionView, _ indexPath: IndexPath) -> UICollectionViewCell {
        let cell: ProgramCollectionViewCell
        
        //TODO: Configure the cell
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath) as! ProgramCollectionViewCell
        
        recalculateProgramCellSize(viewSize ?? collectionView.frame.size, cell)
        
        cell.program = hexFiles[indexPath.row]
        cell.delegate = self
        
        return cell
    }
    
    private func animateFileChange() {
        let oldItems = hexFiles
        let newItems = (try? HexFileManager.stored()) ?? []
        let changes = diff(old: oldItems, new: newItems)
        collectionView.reload(changes: changes, section: 0, updateData: {
            self.hexFiles = newItems
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
        uploadProgram(of: collectionView.cellForItem(at: indexPath) as! ProgramCollectionViewCell)
    }

    // menu

    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: "Edit", action: Selector(("edit"))),
            UIMenuItem(title: "Share", action: Selector(("share")))
        ]
        return true
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(delete(_:)) || action == Selector(("edit")) || action == Selector(("share"))
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    }

    //dummy method for having some selector
    @objc func deleteSelectedProgram(sender: Any) {}

    // MARK: UICollectionViewDelegateFlowLayout

    let programWidthThreshold: CGFloat = 500
    let defaultProgramHeight: CGFloat = 100
    let spacing: CGFloat = 10

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
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
        let alertViewController = UIAlertController(title: "Could not rename \(cell.program.name)", message: "The name \(newName) could not be given to \(cell.program.name). The name for a program must be unique and not empty.", preferredStyle: .alert)
        alertViewController.addAction(UIAlertAction(title: "OK", style: .default)
        { _ in self.dismiss(animated: true, completion: nil) })

        alertViewController.popoverPresentationController?.sourceView = cell
        alertViewController.popoverPresentationController?.sourceRect = cell.name.frame

        self.present(alertViewController, animated: true, completion: nil)
    }

    func programCellSizeDidChange(_ cell: ProgramCollectionViewCell) {
        collectionView.performBatchUpdates({}, completion: nil)
    }

    func uploadProgram(of cell: ProgramCollectionViewCell) {
        FirmwareUpload.showUploadUI(controller: self, program: cell.program, name: cell.program.name) {
            MatrixConnectionViewController.instance.connect()
        }
    }

    func deleteProgram(of cell: ProgramCollectionViewCell) {
        let alert = UIAlertController(title: "Delete?", message: "Do you want to delete \(cell.program.name)?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            do {
                try HexFileManager.delete(file: cell.program)
                self.animateFileChange()
            } catch {
                let alert = UIAlertController(title: "Delete failed", message: "Could not delete \(cell.program.name)\n\(error.localizedDescription)", preferredStyle: .alert)
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
