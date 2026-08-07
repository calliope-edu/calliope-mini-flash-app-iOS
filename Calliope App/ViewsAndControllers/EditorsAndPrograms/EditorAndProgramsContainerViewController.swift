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

    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(
            coder: coder,
            rootView: EditorsAndProgramsView(
                viewModel: EditorsAndProgramsViewModel(
                    renameHexFile: renameProgramDialog,
                    deleteHexFile: deleteProgram
                )
            )
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        MatrixConnectionViewModel.instance.calliopeClass = DiscoveredBLEDevice.self
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
}
