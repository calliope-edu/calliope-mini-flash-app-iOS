//
//  HexFileStoreDialog.swift
//  Calliope App
//

import UIKit

enum HexFileStoreDialogSwiftUI {

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

    public static func showStoreHexUI(
        alertPublisher: Alertable & CanShowProgess,
        hexFile: URL,
        notSaved: @escaping (Error?) -> Void,
        saveCompleted: ((Hex) -> Void)? = nil
    ) {

        let isArcade = isArcadeHexFile(hexFile)
        let isUSBConnected = isUSBCalliopeConnected()

        // Wenn es eine Arcade-Datei ist und KEIN USB verbunden ist
        if isArcade && !isUSBConnected {
            alertPublisher.alert = getArcadeUSBRequiredAlert(alertPublisher: alertPublisher, hexFile: hexFile, notSaved: notSaved)
            return
        }

        // Wenn es eine Arcade-Datei ist und USB verbunden ist
        if isArcade && isUSBConnected {
            alertPublisher.alert = getArcadeTransferAlert(alertPublisher: alertPublisher, hexFile: hexFile, notSaved: notSaved)
            return
        }

        // Standard-Verhalten für normale Hex-Dateien
        alertPublisher.alert = getStandardHexUI(alertPublisher: alertPublisher, hexFile: hexFile, notSaved: notSaved)
    }

    /// Alert für Arcade-Dateien wenn KEIN USB verbunden ist
    private static func getArcadeUSBRequiredAlert(
        alertPublisher: Alertable,
        hexFile: URL,
        notSaved: @escaping (Error?) -> Void,
        saveCompleted: ((Hex) -> Void)? = nil
    ) -> ArcadeUSBRequiredAlert {
        return ArcadeUSBRequiredAlert(
            saved: {
                saveFileWithNameAlert(alertPublisher: alertPublisher, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
            },
            closed: {
                notSaved(nil)
            }
        )
    }

    /// Alert für Arcade-Dateien wenn USB verbunden ist
    private static func getArcadeTransferAlert(
        alertPublisher: Alertable & CanShowProgess,
        hexFile: URL,
        notSaved: @escaping (Error?) -> Void,
        saveCompleted: ((Hex) -> Void)? = nil
    ) -> ArcadeTransferAlert {
        return ArcadeTransferAlert(
            saved: {
                saveFileWithNameAlert(alertPublisher: alertPublisher, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
            },
            transfer: {
                let program = DefaultProgram(
                    programName: hexFile.deletingPathExtension().lastPathComponent,
                    url: hexFile.standardizedFileURL.relativeString
                )
                program.downloadFile = false
                FirmwareUploadSwiftUI.showUploadUI(alertPublisher: alertPublisher, program: program) {
                    MatrixConnectionViewModel.instance.connect()
                }
            },
            closed: {
                notSaved(nil)
            }
        )
    }

    /// Standard UI für normale Hex-Dateien
    private static func getStandardHexUI(
        alertPublisher: Alertable & CanShowProgess,
        hexFile: URL,
        notSaved: @escaping (Error?) -> Void,
        saveCompleted: ((Hex) -> Void)? = nil
    ) -> StandardHexUIAlert {
        return StandardHexUIAlert(
            saved: {
                saveFileWithNameAlert(alertPublisher: alertPublisher, hexFile: hexFile, notSaved: notSaved, saveCompleted: saveCompleted)
            },
            transfer: {
                let program = DefaultProgram(
                    programName: hexFile.deletingPathExtension().lastPathComponent,
                    url: hexFile.standardizedFileURL.relativeString
                )
                program.downloadFile = false
                FirmwareUploadSwiftUI.showUploadUI(alertPublisher: alertPublisher, program: program) {
                    MatrixConnectionViewModel.instance.connect()
                }
            },
            closed: {}
        )
    }

    private static func saveFileWithNameAlert(
        alertPublisher: Alertable,
        hexFile: URL,
        notSaved: @escaping (Error?) -> Void,
        saveCompleted: ((Hex) -> Void)? = nil
    ) {
        let name = hexFile.deletingPathExtension().lastPathComponent

        let data: Data
        do {
            data = try hexFile.asData()
        } catch {
            notSaved(error)
            return
        }

        let alert = SaveFileWithNameAlert(
            save: { enteredName in
                LogNotify.debug(enteredName)
                do {
                    guard let file = try HexFileManager.store(name: enteredName, data: data) else {
                        return
                    }
                    saveCompleted?(file)
                } catch {
                    notSaved(error)
                }
            },
            dontSave: { _ in
                notSaved(nil)
            },
            defaultName: name
        )
        DispatchQueue.main.async {
            alertPublisher.alert = alert
        }
    }
}
