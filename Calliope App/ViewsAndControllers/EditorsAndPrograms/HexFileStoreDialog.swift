//
//  HexFileStoreDialog.swift
//  Calliope App
//
//  Created by Tassilo Karge on 01.09.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit



enum HexFileStoreDialog {
    public static func showStoreHexUI(controller: UIViewController, hexFile: URL,
                                      notSaved: @escaping (Error?) -> (),
                                      saveCompleted: ((Hex) -> ())? = nil) {

        let name = hexFile.deletingPathExtension().lastPathComponent

        let data: Data
        do {
            data = try hexFile.asData()
        } catch {
            notSaved(error)
            return
        }

        let alert = UIAlertController(title: NSLocalizedString("Save Program", comment: ""),
                                      message: NSLocalizedString("Please choose a name", comment: "In dialog to choose name for new program"),
                                      preferredStyle: .alert)

        alert.addTextField { textField in
            textField.keyboardType = .default
            textField.text = name
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("Don´t save", comment: ""), style: .destructive) {_ in
            notSaved(nil)
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("Save Program", comment: ""), style: .default) { _ in
            do {
                let enteredName = alert.textFields?[0].text ?? name
                //TODO clean up name
                let file = try HexFileManager.store(name: enteredName, data: data)
                //TODO watch for file name duplicates
                saveCompleted?(file)
            } catch {
                notSaved(error)
            }
        })

        controller.present(alert, animated: true)
    }
}
