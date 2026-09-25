//
//  AppAlerts.swift
//  Calliope App
//
//  Created by Calliope on 07.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

// Named constructors for every AppAlert used across the app. The AppAlert type itself and the
// alert engine live in Alert.swift. For a one-off alert that doesn't need a name here, just call
// AppAlert(title:message:actions:) or AppAlert(title:message:textField:) directly.

extension AppAlert {
    static func arcadeUSBRequired(saved: @escaping () -> Void, closed: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Arcade-Datei", comment: ""),
            message: NSLocalizedString(
                "Arcade-Dateien können nur per USB-Kabel übertragen werden. Bitte verbinde deinen Calliope mini per USB oder sichere die Datei für später.",
                comment: ""
            ),
            actions: [
                StandardAlertAction(NSLocalizedString("Sichern", comment: ""), handler: saved),
                StandardAlertAction(NSLocalizedString("Schließen", comment: ""), role: .cancel, handler: closed),
            ]
        )
    }

    static func arcadeTransfer(saved: @escaping () -> Void, transfer: @escaping () -> Void, closed: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Arcade-Datei", comment: ""),
            message: NSLocalizedString("Möchtest du die Arcade-Datei auf deinen Calliope mini übertragen oder sichern?", comment: ""),
            actions: [
                StandardAlertAction(NSLocalizedString("Sichern", comment: ""), handler: saved),
                StandardAlertAction(NSLocalizedString("Übertragen (USB)", comment: ""), handler: transfer),
                StandardAlertAction(NSLocalizedString("Schließen", comment: ""), role: .cancel, handler: closed),
            ]
        )
    }

    static func standardHexUI(saved: @escaping () -> Void, transfer: @escaping () -> Void, closed: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Datei geöffnet", comment: ""),
            message: NSLocalizedString("Möchtest du die Datei sichern oder auf deinen Calliope mini übertragen?", comment: ""),
            actions: [
                StandardAlertAction(NSLocalizedString("Sichern", comment: ""), handler: saved),
                StandardAlertAction(NSLocalizedString("Übertragen", comment: ""), handler: transfer),
                StandardAlertAction(NSLocalizedString("Schließen", comment: ""), role: .cancel, handler: closed),
            ]
        )
    }

    static func saveFileWithName(
        save: @escaping (_ text: String) -> Void,
        dontSave: @escaping (_ text: String) -> Void,
        defaultName: String
    ) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Save Program", comment: ""),
            message: NSLocalizedString("Please choose a name", comment: ""),
            textField: .init(
                hint: "Program Name",
                defaultValue: defaultName,
                actions: [
                    TextFieldAlertAction(NSLocalizedString("Save Program", comment: ""), handler: save),
                    TextFieldAlertAction(NSLocalizedString("Don't save", comment: ""), handler: dontSave),
                ]
            )
        )
    }

    static func waitForProgramDownload() -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Wait a little", comment: ""),
            message: NSLocalizedString("The program is being downloaded. Please wait a little.", comment: ""),
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
        )
    }

    static func programDownloadSuccess(upload: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Download finished", comment: ""),
            message: NSLocalizedString("The program is downloaded. Do you want to upload it now?", comment: ""),
            actions: [
                StandardAlertAction(NSLocalizedString("Yes", comment: ""), handler: upload),
                StandardAlertAction(NSLocalizedString("No", comment: ""), handler: {}),
            ]
        )
    }

    static func programDownloadFailed(error: String?, completion: @escaping () -> Void) -> AppAlert {
        let reason = error ?? NSLocalizedString("The downloaded program is empty", comment: "")
        return AppAlert(
            title: NSLocalizedString("Program download failed", comment: ""),
            message: String(format: NSLocalizedString("The program is not ready. The reason is: %@", comment: ""), reason),
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: completion)],
            severity: .warning
        )
    }

    static func uploadConfirmation(name: String?, upload: @escaping () -> Void) -> AppAlert {
        let defaultName = NSLocalizedString("the program", comment: "")
        return AppAlert(
            title: NSLocalizedString("Upload?", comment: ""),
            message: String(format: NSLocalizedString("Do you want to upload %@ to your Calliope mini?", comment: ""), name ?? defaultName),
            actions: [
                StandardAlertAction(NSLocalizedString("Upload", comment: ""), handler: upload),
                StandardAlertAction(NSLocalizedString("Cancel", comment: ""), handler: {}),
            ]
        )
    }

    static func uploadFailed(goToInformation: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Upload failed", comment: ""),
            message: NSLocalizedString(
                "The program does not seem to match the version of your Calliope mini. Please check the hardware selection in your editor again.",
                comment: ""
            ),
            actions: [
                StandardAlertAction(NSLocalizedString("Futher Information", comment: ""), handler: goToInformation),
                StandardAlertAction(NSLocalizedString("Cancel", comment: ""), handler: {}),
            ],
            severity: .warning
        )
    }

    static func cannotUpload() -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Cannot upload", comment: "Übertragung nicht möglich"),
            message: NSLocalizedString(
                "There is no connected Calliope mini in DFU mode",
                comment: "Es konnte kein Calliope mini gefunden werden"
            ),
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})],
            severity: .warning
        )
    }

    /// Shown mid-upload when an Arcade file needs the app to be switched into USB mode.
    /// Not to be confused with `.arcadeUSBRequired`, which is shown when *saving* an Arcade file without USB connected.
    static func arcadeUsbModeRequired(onOpenUsbMode: @escaping () -> Void, onCancel: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("USB-Verbindung erforderlich", comment: "USB connection required"),
            message: NSLocalizedString(
                "Arcade-Programme können nur per USB auf den Calliope mini übertragen werden.\n\nBitte verbinde den Calliope mini per USB-Kabel und wähle den MINI-Ordner aus.",
                comment: "Arcade programs can only be transferred via USB"
            ),
            actions: [
                StandardAlertAction(NSLocalizedString("USB-Modus öffnen", comment: "Open USB mode"), handler: onOpenUsbMode),
                StandardAlertAction(NSLocalizedString("Abbrechen", comment: "Cancel"), role: .cancel, handler: onCancel),
            ]
        )
    }

    static func ok(title: String, message: String? = nil, completion: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: title,
            message: message,
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: completion)]
        )
    }

    static func webViewNavigationError(error: Error) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Navigation Failed", comment: ""),
            message: error.localizedDescription,
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})],
            severity: .warning
        )
    }

    static func renameProgram(defaultName: String, onRename: @escaping (_ text: String) -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Enter the new program title", comment: ""),
            textField: .init(
                hint: "Program Name",
                defaultValue: defaultName,
                actions: [
                    TextFieldAlertAction(NSLocalizedString("OK", comment: ""), handler: onRename),
                    TextFieldAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { _ in }),
                ]
            )
        )
    }

    static func deleteProgram(program: HexFile, onDelete: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Delete?", comment: ""),
            message: String(format: NSLocalizedString("Do you want to delete %@?", comment: ""), program.name),
            actions: [
                StandardAlertAction(NSLocalizedString("Delete", comment: ""), role: .destructive, handler: onDelete),
                StandardAlertAction(NSLocalizedString("Cancel", comment: ""), role: .cancel, handler: {}),
            ]
        )
    }

    static func deleteProgramFailed(program: HexFile, error: Error) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Delete failed", comment: ""),
            message: String(format: NSLocalizedString("Could not delete %@\n", comment: ""), program.name) + error.localizedDescription,
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})],
            severity: .warning
        )
    }

    static func renameFailed(oldName: String, newName: String) -> AppAlert {
        AppAlert(
            title: String(format: NSLocalizedString("Could not rename %@", comment: ""), oldName),
            message: String(
                format: NSLocalizedString("The name %@ could not be given to %@. The name for a program must be unique and not empty.", comment: ""),
                newName,
                oldName
            ),
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})],
            severity: .warning
        )
    }

    static func renameProject(defaultName: String, onRename: @escaping (_ text: String) -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Change project name", comment: ""),
            message: NSLocalizedString("Enter the new project name", comment: ""),
            textField: .init(
                hint: NSLocalizedString("New project", comment: ""),
                defaultValue: defaultName,
                actions: [
                    TextFieldAlertAction(NSLocalizedString("OK", comment: ""), handler: onRename),
                    TextFieldAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { _ in }),
                ]
            )
        )
    }

    static func exportCSVName(onOk: @escaping (_ text: String) -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Export Data", comment: ""),
            message: NSLocalizedString("Enter the CSV file name", comment: ""),
            textField: .init(
                hint: "CSV_Export",
                defaultValue: nil,
                actions: [
                    TextFieldAlertAction(NSLocalizedString("OK", comment: ""), handler: { text in
                        onOk(text.isEmpty ? "CSV_Export" : text)
                    }),
                    TextFieldAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { _ in }),
                ]
            )
        )
    }

    static func connectCalliopeRequired() -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Calliope mini verbinden!", comment: ""),
            message: NSLocalizedString("Verbindung notwendig, um Daten anzeigen zu lassen.", comment: ""),
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
        )
    }

    static func wrongStorageLocation() -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Wrong storage location", comment: ""),
            message: NSLocalizedString("You have not selected a Calliope folder as storage location", comment: ""),
            actions: [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})],
            severity: .warning
        )
    }

    static func bluetoothDeactivated(openSettings: @escaping () -> Void, ok: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Bluetooth deactivated", comment: "Bluetooth is turned off"),
            message: NSLocalizedString("Bluetooth must be activated to send data to Calliope mini!", comment: "Bluetooth required message"),
            actions: [
                StandardAlertAction(NSLocalizedString("Open Settings", comment: "Open Settings button"), handler: openSettings),
                StandardAlertAction("OK", role: .cancel, handler: ok),
            ],
            severity: .warning
        )
    }

    static func bluetoothResetRequired(openSettings: @escaping () -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Bluetooth-Verbindung zurücksetzen", comment: "Reset Bluetooth connection"),
            message: NSLocalizedString(
                "Der Calliope mini wurde schon einmal gekoppelt. Diese Informationen müssen erneut angelegt werden:\n\n1. Gehe zu Einstellungen → Bluetooth\n2. Tippe auf das (i) neben dem Calliope mini\n3. Wähle \"Dieses Gerät ignorieren\"\n4. Kehre zur Calliope mini App zurück und verbinde erneut",
                comment: "Instructions to reset Bluetooth pairing"
            ),
            actions: [
                StandardAlertAction(NSLocalizedString("Einstellungen öffnen", comment: "Open Settings"), handler: openSettings),
                StandardAlertAction("OK", role: .cancel, handler: {}),
            ],
            severity: .warning
        )
    }

    static func newProjectName(onCreate: @escaping (_ text: String) -> Void) -> AppAlert {
        AppAlert(
            title: NSLocalizedString("Enter an Projectname for the new Project", comment: ""),
            textField: .init(
                hint: "Calliope Project",
                defaultValue: nil,
                actions: [
                    TextFieldAlertAction(NSLocalizedString("OK", comment: ""), handler: { text in
                        onCreate(text.isEmpty ? "Calliope Project" : text)
                    }),
                    TextFieldAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { _ in }),
                ]
            )
        )
    }
}
