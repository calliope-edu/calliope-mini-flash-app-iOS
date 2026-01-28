//
//  HexFileStoreDialog.swift
//  Calliope App
//

import UIKit

enum HexFileStoreDialog {
    
    /// Prüft ob es sich um eine Arcade Hex-Datei handelt
    private static func isArcadeHexFile(_ hexFile: URL) -> Bool {
        let file = HexFile(url: hexFile, name: hexFile.lastPathComponent, date: Date())
        let hexTypes = file.getHexTypes()
        return hexTypes.contains(.arcade)
    }
    
    /// Prüft ob ein USB-Calliope verbunden ist
    private static func isUSBCalliopeConnected() -> Bool {
        return USBCalliope.calliopeLocation != nil
    }
    
    public static func showStoreHexUI(controller: UIViewController, hexFile: URL,
                                      notSaved: @escaping (Error?) -> (),
                                      saveCompleted: ((Hex) -> ())? = nil) {
        
        let isArcade = isArcadeHexFile(hexFile)
        let isUSBConnected = isUSBCalliopeConnected()
        
        // Wenn es eine Arcade-Datei ist und KEIN USB verbunden ist
        if isArcade && !isUSBConnected {
            showArcadeUSBRequiredAlert(controller: controller, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
            return
        }
        
        // Wenn es eine Arcade-Datei ist und USB verbunden ist
        if isArcade && isUSBConnected {
            showArcadeTransferAlert(controller: controller, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
            return
        }
        
        // Standard-Verhalten für normale Hex-Dateien
        showStandardHexUI(controller: controller, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
    }
    
    /// Alert für Arcade-Dateien wenn KEIN USB verbunden ist
    private static func showArcadeUSBRequiredAlert(controller: UIViewController, hexFile: URL,
                                                    notSaved: @escaping (Error?) -> (),
                                                    saveCompleted: ((Hex) -> ())? = nil) {
        let alert = UIAlertController(
            title: NSLocalizedString("Arcade-Datei", comment: ""),
            message: NSLocalizedString("Arcade-Dateien können nur per USB-Kabel übertragen werden. Bitte verbinde deinen Calliope mini per USB oder sichere die Datei für später.", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Sichern", comment: ""), style: .default) { _ in
            saveFileWithNameAlert(controller: controller, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Schließen", comment: ""), style: .cancel) { _ in
            notSaved(nil)
        })
        
        controller.present(alert, animated: true)
    }
    
    /// Alert für Arcade-Dateien wenn USB verbunden ist
    private static func showArcadeTransferAlert(controller: UIViewController, hexFile: URL,
                                                 notSaved: @escaping (Error?) -> (),
                                                 saveCompleted: ((Hex) -> ())? = nil) {
        let alert = UIAlertController(
            title: NSLocalizedString("Arcade-Datei", comment: ""),
            message: NSLocalizedString("Möchtest du die Arcade-Datei auf deinen Calliope mini übertragen oder sichern?", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Sichern", comment: ""), style: .default) { _ in
            saveFileWithNameAlert(controller: controller, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Übertragen (USB)", comment: ""), style: .default) { _ in
            let program = DefaultProgram(programName: hexFile.deletingPathExtension().lastPathComponent, url: hexFile.standardizedFileURL.relativeString)
            program.downloadFile = false
            FirmwareUpload.showUploadUI(controller: controller, program: program) {
                MatrixConnectionViewController.instance.connect()
            }
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Schließen", comment: ""), style: .cancel) { _ in
            notSaved(nil)
        })
        
        controller.present(alert, animated: true)
    }
    
    /// Standard UI für normale Hex-Dateien
    private static func showStandardHexUI(controller: UIViewController, hexFile: URL,
                                          notSaved: @escaping (Error?) -> (),
                                          saveCompleted: ((Hex) -> ())? = nil) {
        let alertStart = UIAlertController(
            title: NSLocalizedString("Datei geöffnet", comment: ""),
            message: NSLocalizedString("Möchtest du die Datei sichern oder auf deinen Calliope mini übertragen?", comment: ""),
            preferredStyle: .alert
        )
        
        alertStart.addAction(UIAlertAction(title: NSLocalizedString("Sichern", comment: ""), style: .default) { _ in
            saveFileWithNameAlert(controller: controller, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
        })
        
        alertStart.addAction(UIAlertAction(title: NSLocalizedString("Übertragen", comment: ""), style: .default) { _ in
            let program = DefaultProgram(programName: hexFile.deletingPathExtension().lastPathComponent, url: hexFile.standardizedFileURL.relativeString)
            program.downloadFile = false
            FirmwareUpload.showUploadUI(controller: controller, program: program) {
                MatrixConnectionViewController.instance.connect()
            }
        })
        
        alertStart.addAction(UIAlertAction(title: NSLocalizedString("Schließen", comment: ""), style: .cancel))
        controller.present(alertStart, animated: true)
    }

    private static func saveFileWithNameAlert(controller: UIViewController, hexFile: URL,
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

        let alert = UIAlertController(
            title: NSLocalizedString("Save Program", comment: ""),
            message: NSLocalizedString("Please choose a name", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.keyboardType = .default
            textField.text = name
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Don´t save", comment: ""), style: .destructive) { _ in
            notSaved(nil)
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Save Program", comment: ""), style: .default) { _ in
            do {
                let enteredName = alert.textFields?[0].text ?? name
                guard let file = try HexFileManager.store(name: enteredName, data: data) else {
                    return
                }
                saveCompleted?(file)
            } catch {
                notSaved(error)
            }
        })

        controller.present(alert, animated: true)
    }
}
