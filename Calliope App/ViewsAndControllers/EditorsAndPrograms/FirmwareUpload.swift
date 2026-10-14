//
//  FirmwareUploadViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import NordicDFU
import UIKit

class FirmwareUpload {

    public static func showUIForDownloadableProgram(
        alertPublisher: Alertable,
        program: DownloadableHexFile,
        name: String = NSLocalizedString("the program", comment: ""),
        completion: ((_ success: Bool) -> Void)? = nil
    ) {
        if program.calliopeV1andV2Bin.count != 0 {
            DispatchQueue.main.async {
                FirmwareUpload.showUploadUI(alertPublisher: alertPublisher, program: program) {
                    completion?(true)
                    MatrixConnectionViewModel.instance.connect()
                }
            }
        } else {
            alertPublisher.setAlert(.waitForProgramDownload())
            program.load { error in
                DispatchQueue.main.async {
                    if error == nil, program.calliopeV1andV2Bin.count != 0 {
                        LogNotify.debug("Successfully finished downloading program")
                        let successAlert = AppAlert.programDownloadSuccess(upload: {
                            DispatchQueue.main.async {
                                LogNotify.debug("Upload confirmed")
                                FirmwareUpload.uploadWithoutConfirmation(alertPublisher: alertPublisher, program: program) {
                                    completion?(true)
                                }
                            }
                        })
                        alertPublisher.setAlert(successAlert)
                    } else {
                        LogNotify.error("Encountered error during program download: " + (error?.localizedDescription ?? ""))
                        let errorAlert = AppAlert.programDownloadFailed(error: error?.localizedDescription, completion: { completion?(false) })
                        alertPublisher.setAlert(errorAlert)
                    }
                }
            }
        }
    }

    public static func showUploadUI(
        alertPublisher: Alertable,
        program: Hex,
        name: String = NSLocalizedString("the program", comment: ""),
        completion: (() -> Void)? = nil
    ) {
        let connection = MatrixConnectionViewModel.instance
        guard connection.usageReadyCalliope != nil || (connection.isInUsbMode && connection.isSharedIpad) else {
            LogNotify.error("No calliope connected. Canceling upload.")
            alertPublisher.setAlert(.cannotUpload())
            MatrixConnectionViewModel.instance.animateBounce()
            return
        }

        let confirmationAlert = AppAlert.uploadConfirmation(
            name: name,
            upload: {
                DispatchQueue.main.async {
                    uploadWithoutConfirmation(alertPublisher: alertPublisher, program: program, completion: completion)
                }
            }
        )
        alertPublisher.setAlert(confirmationAlert)
    }

    @MainActor public static func uploadWithoutConfirmation(
        alertPublisher: Alertable,
        program: Hex,
        completion: (() -> Void)? = nil
    ) {
        // NEU: Prüfe ob es eine Arcade-Datei ist
        let hexTypes = program.getHexTypes()
        if hexTypes.contains(.arcade) {
            // Arcade-Dateien können nur per USB übertragen werden
            // Prüfe zuerst ob bereits eine USB-Verbindung besteht
            if MatrixConnectionViewModel.instance.isUSBConnected() {
                // USB ist bereits verbunden, fahre mit Upload fort
                // (Der Code fällt durch zu uploadAlert unten)
            } else {
                // Keine USB-Verbindung, zeige Alert
                showArcadeUSBAlert(alertPublisher: alertPublisher, completion: completion)
                return
            }
        }

        let target = MatrixConnectionViewModel.instance.usageReadyCalliope
        let isUSB = target is USBCalliope
        // On Shared iPad the system export picker is the transfer UI; failures there need a standalone alert.
        let usesExportPicker = (target as? USBCalliope)?.useExportPicker == true
        LogNotify.debug("useExportPicker = \(usesExportPicker)")

        weak var job: FlashJob?
        var progressStarted = false
        job = flashService.flash(program) { event in
            let progress = UploadProgressViewModel.instance
            switch event {
            case .progress(let value):
                if !progressStarted {
                    progressStarted = true
                    progress.startUpload(
                        isIndeterminate: value == nil,
                        statusText: value == nil ? NSLocalizedString("Transferring to Calliope", comment: "") : ""
                    )
                    // Bound to this job, so a stale panel action cannot cancel a newer upload.
                    progress.cancelAction = { job?.cancel() }
                    progress.connectionLostAction = { job?.connectionLost() }
                } else if let value {
                    progress.updateProgress(value)
                }
            case .completed, .cancelled:
                progress.finishUpload()
                completion?()
            case .failed(let error):
                progress.finishUpload()
                presentFailure(error, alertPublisher: alertPublisher, isUSB: isUSB, usesExportPicker: usesExportPicker)
            }
        }
    }

    private static func presentFailure(_ error: UploadError, alertPublisher: Alertable, isUSB: Bool, usesExportPicker: Bool) {
        switch error {
        case .notConnected:
            alertPublisher.setAlert(.cannotUpload())
            MatrixConnectionViewModel.instance.animateBounce()
        case .connectionLost:
            break
        case .incompatibleHex:
            if usesExportPicker {
                presentStandalone(makeHexMismatchAlert(informationLink: hardwareInformationLink))
            } else {
                alertPublisher.setAlert(.uploadFailed(goToInformation: openHardwareInformation))
            }
        case .dfu:
            if usesExportPicker {
                // A rejected transfer (DAPLink FAIL.TXT) is detected in USBCalliope and shows the same alert from there.
                presentStandalone(makeUsbTransferFailureAlert(
                    message: NSLocalizedString("The file could not be transferred. Unplug the Calliope mini and plug it in again before you transfer the next program.", comment: "")))
            } else if isUSB {
                alertPublisher.setAlert(.usbUploadFailed())
            } else {
                alertPublisher.setAlert(.uploadFailed(goToInformation: openHardwareInformation))
            }
        }
    }

    private static let hardwareInformationLink = "https://calliope.cc/programmieren/mobil/ipad#hardware"

    private static func openHardwareInformation() {
        if let url = URL(string: hardwareInformationLink) {
            UIApplication.shared.open(url)
        }
    }

    // Temporary owner until UploadViewModel gets the service injected.
    private static let flashService = FlashService(connection: MatrixDeviceConnectionService(viewModel: .instance))

    // NEU: Hilfsmethode für Arcade USB Alert
    private static func showArcadeUSBAlert(alertPublisher: Alertable, completion: (() -> Void)?) {
        let alert = AppAlert.arcadeUsbModeRequired(
            onOpenUsbMode: {
                // Wechsle in USB-Modus
                // Expand the matrix connection view if it's collapsed
                MatrixConnectionViewModel.instance.menuExpanded = true

                // Switch to USB mode (this triggers switchChanged which updates the UI)
                MatrixConnectionViewModel.instance.isInUsbMode = true

                // Open the file picker after a short delay to allow the UI to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    MatrixConnectionViewModel.instance.startUsbConnect()
                }
                completion?()
            },
            onCancel: {
                completion?()
            }
        )
        alertPublisher.setAlert(alert)
    }
    
    /// Presents an alert without relying on our progress alert being on screen —
    /// in export-picker mode there is none.
    private static func presentStandalone(_ alert: UIAlertController) {
        guard let presenter = FirmwareUpload.topMostViewController() else { return }
        DispatchQueue.main.async {
            presenter.present(alert, animated: true)
        }
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

    /// DIAGNOSTICS (Shared-iPad USB investigation): shows what happened during
    /// the last transfer attempt, including DAPLink's verdict, plus an action to
    /// share the full log. Remove together with
    /// `USBCalliope.showTransferDiagnostics` once the cause is understood.
    static func presentTransferDiagnosticsAlert(verdict: String) {
        let excerpt = LogNotify.recentLines(
            matching: ["Export picker", "Editor download", "USB Transfer"], limit: 12)

        let alert = UIAlertController(
            title: NSLocalizedString("Transfer diagnostics", comment: "Diagnostics alert title"),
            message: verdict + "\n\n" + excerpt,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Share log", comment: "Action to share the in-app log"),
            style: .default) { _ in
                FirmwareUpload.presentLogShareSheet()
            })
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))

        guard let presenter = topMostViewController() else { return }
        presenter.present(alert, animated: true)
    }

    /// Failure alert for a USB transfer, with an action to share the recent log.
    ///
    /// A Shared iPad can only be updated through TestFlight, where no console
    /// output exists — so the log has to be reachable from inside the app for a
    /// problem to be reportable at all.
    static func makeUsbTransferFailureAlert(message: String) -> UIAlertController {
        let alert = UIAlertController(
            title: NSLocalizedString("Upload failed!", comment: ""),
            message: message,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Share log", comment: "Action to share the in-app log"),
            style: .default) { _ in
                FirmwareUpload.presentLogShareSheet()
            })
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))
        return alert
    }

    /// Offers the buffered log through the normal share sheet.
    private static func presentLogShareSheet() {
        guard let presenter = topMostViewController() else { return }

        let activityController = UIActivityViewController(
            activityItems: [LogNotify.recentLog], applicationActivities: nil)
        // On iPad an activity sheet must have an anchor, otherwise it traps.
        activityController.popoverPresentationController?.sourceView = presenter.view
        activityController.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
        activityController.popoverPresentationController?.permittedArrowDirections = []
        presenter.present(activityController, animated: true)
    }

    private static func makeHexMismatchAlert(informationLink: String) -> UIAlertController {
        let alert = UIAlertController(
            title: NSLocalizedString("Upload failed", comment: ""),
            message: String(format: NSLocalizedString("The program does not seem to match the version of your Calliope mini. Please check the hardware selection in your editor again.", comment: "")),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(
            UIAlertAction(title: NSLocalizedString("Further Information", comment: ""), style: .default) { _ in
                if let url = URL(string: informationLink) {
                    UIApplication.shared.open(url)
                }
            })
        return alert
    }
}
