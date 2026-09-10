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

    public static func showStoreHexUI(
        alertPublisher: Alertable,
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

    /// "Share" — hands the picked file to the system share sheet.
    private static func presentShareSheet(for hexFile: URL) {
        guard let presenter = topMostViewController() else { return }
        let activityViewController = UIActivityViewController(activityItems: [hexFile], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = presenter.view
        activityViewController.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
        presenter.present(activityViewController, animated: true)
    }

    /// Walks the active scene's key window to find the top-most presented
    /// view controller, since there is no stored UIKit controller reference
    /// to present from in the SwiftUI-driven flow.
    private static func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let keyWindow = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
            ?? scenes.flatMap { $0.windows }.first
        return keyWindow?.rootViewController?.topMostPresented()
    }

    /// Alert für Arcade-Dateien wenn KEIN USB verbunden ist
    private static func getArcadeUSBRequiredAlert(
        alertPublisher: Alertable,
        hexFile: URL,
        notSaved: @escaping (Error?) -> Void,
        saveCompleted: ((Hex) -> Void)? = nil
    ) -> AppAlert {
        return .arcadeUSBRequired(
            shared: {
                presentShareSheet(for: hexFile)
            },
            closed: {
                notSaved(nil)
            }
        )
    }

    /// Alert für Arcade-Dateien wenn USB verbunden ist
    private static func getArcadeTransferAlert(
        alertPublisher: Alertable,
        hexFile: URL,
        notSaved: @escaping (Error?) -> Void,
        saveCompleted: ((Hex) -> Void)? = nil
    ) -> AppAlert {
        return .arcadeTransfer(
            shared: {
                presentShareSheet(for: hexFile)
            },
            transfer: {
                let program = DefaultProgram(
                    programName: hexFile.deletingPathExtension().lastPathComponent,
                    url: hexFile.standardizedFileURL.relativeString
                )
                program.downloadFile = false
                FirmwareUpload.showUploadUI(alertPublisher: alertPublisher, program: program) {
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
        alertPublisher: Alertable,
        hexFile: URL,
        notSaved: @escaping (Error?) -> Void,
        saveCompleted: ((Hex) -> Void)? = nil
    ) -> AppAlert {
        // "(USB)" while a USB Calliope is the active connection, so it is
        // obvious which way the program takes.
        let transferTitle = MatrixConnectionViewModel.instance.isUSBConnected()
            ? NSLocalizedString("Übertragen (USB)", comment: "")
            : NSLocalizedString("Übertragen", comment: "")
        return .standardHexUI(
            transferTitle: transferTitle,
            shared: {
                presentShareSheet(for: hexFile)
            },
            transfer: {
                let program = DefaultProgram(
                    programName: hexFile.deletingPathExtension().lastPathComponent,
                    url: hexFile.standardizedFileURL.relativeString
                )
                program.downloadFile = false
                FirmwareUpload.showUploadUI(alertPublisher: alertPublisher, program: program) {
                    MatrixConnectionViewModel.instance.connect()
                }
            },
            closed: {}
        )
    }
}
