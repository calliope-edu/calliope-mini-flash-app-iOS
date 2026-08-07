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
}
