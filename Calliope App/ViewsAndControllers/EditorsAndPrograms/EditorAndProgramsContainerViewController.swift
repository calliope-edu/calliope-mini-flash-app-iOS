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

    @IBOutlet var editorTopToSafeArea: NSLayoutConstraint?
    @IBOutlet var editorBottomToSafeArea: NSLayoutConstraint?
    var editorsHeightConstraint: NSLayoutConstraint?

    var programsHeightConstraint: NSLayoutConstraint?

    var editorsKvo: Any?
    var programsKvo: Any?
    var bottomInsetKvo: Any?

    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(
            coder: coder,
            rootView: EditorsAndProgramsView(
                viewModel: EditorsAndProgramsViewModel(
                    openEditor: openEditor,
                    uploadDownloadableProgram: uploadDownloadableProgram,
                    openQRCodeView: openQRCodeView,
                    openFileDialog: navigateToImportFile,
                    uploadHexFile: uploadHexFile,
                    renameHexFile: renameProgramDialog,
                    deleteHexFile: deleteProgram
                )
            )
        )
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
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
        scanButton?.tintColor = UIColor.white
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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

    func uploadDefaultV3Program(_ sender: Any) {
        let program = DefaultProgram(
            programName: NSLocalizedString("Calliope mini V3", comment: ""),
            url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV3Url.rawValue)!
        )
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }

    func uploadDefaultV2And1Program(_sender: Any) {
        let program = DefaultProgram(
            programName: NSLocalizedString("Calliope mini V1 + 2", comment: ""),
            url: UserDefaults.standard.string(forKey: SettingsKey.defaultProgramV1AndV2Url.rawValue)!
        )
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }

    func navigateToImportFile() {
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

    func openEditor(editor: EditorTileConfig) {
        switch editor.name {
        case "Makecode":
            performSegue(withIdentifier: "showMakecode", sender: nil)
        case "Open Roberta Lab":
            performSegue(withIdentifier: "openOpenRobertaLab", sender: nil)
        case "Calliope mini Blocks":
            performSegue(withIdentifier: "openCalliopeMiniBlocks", sender: nil)
        case "Micropython":
            performSegue(withIdentifier: "openMicropython", sender: nil)
        case "Arcade (USB only)":
            performSegue(withIdentifier: "openArcade", sender: nil)
        default:
            LogNotify.error("Tried to open unkown editor \(editor.name).")
        }
    }

    func uploadDownloadableProgram(_ program: DownloadableHexFile) {
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }

    func openQRCodeView() {
        performSegue(withIdentifier: "openQRCodeView", sender: nil)
    }

    func uploadHexFile(program: HexFile) {
        FirmwareUpload.showUploadUI(controller: self, program: program, name: program.name) {
            MatrixConnectionViewController.instance.connect()
        }
    }

    func deleteProgram(program: HexFile) {
        let alert = UIAlertController(title: NSLocalizedString("Delete?", comment: ""), message: String(format: NSLocalizedString("Do you want to delete %@?", comment: ""), program.name), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in
            do {
                try HexFileManager.delete(file: program)
            } catch {
                let alert = UIAlertController(title: NSLocalizedString("Delete failed", comment: ""), message: String(format: "Could not delete %@\n", program.name) + error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
    }

    private func renameProgramDialog(_ program: HexFile) {
        let alertController = UIAlertController(
            title: NSLocalizedString("Enter the new program title", comment: ""),
            message: nil,
            preferredStyle: .alert
        )
        alertController.addTextField { (textField) in
            textField.text = program.name
        }

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let name = textField.text {
                if name != "" {
                    var renamableProgram = program
                    renamableProgram.name = name
                    if renamableProgram.name != name {
                        //rename was not successful
                        self.renameFailed(renamableProgram, name)
                    }
                }
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }

    func renameFailed(_ program: HexFile, _ newName: String) {
        let alertViewController = UIAlertController(
            title: String(format: NSLocalizedString("Could not rename %@", comment: ""), program.name),
            message: String(
                format: NSLocalizedString("The name %@ could not be given to %@. The name for a program must be unique and not empty.", comment: ""),
                newName,
                program.name
            ),
            preferredStyle: .alert
        )
        alertViewController.addAction(
            UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
                self.dismiss(animated: true, completion: nil)
            }
        )

        self.present(alertViewController, animated: true, completion: nil)
    }

    @IBSegueAction func initializeMakeCode(_ coder: NSCoder) -> EditorViewController? {
        EditorViewController(coder: coder, editor: MakeCode())
    }

    @IBSegueAction func initializeOpenRobertaLab(_ coder: NSCoder) -> EditorViewController? {
        EditorViewController(coder: coder, editor: RobertaEditor())

    }

    @IBSegueAction func initializeMicropython(_ coder: NSCoder) -> EditorViewController? {
        EditorViewController(coder: coder, editor: MicroPython())
    }
}
