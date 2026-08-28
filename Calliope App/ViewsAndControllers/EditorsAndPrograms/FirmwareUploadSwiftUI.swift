//
//  FirmwareUploadViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import NordicDFU
import UIKit

class FirmwareUploadSwiftUI {

    public static func showUIForDownloadableProgram(
        alertPublisher: Alertable,
        program: DownloadableHexFile,
        name: String = NSLocalizedString("the program", comment: ""),
        completion: ((_ success: Bool) -> Void)? = nil
    ) {
        if program.calliopeV1andV2Bin.count != 0 {
            DispatchQueue.main.async {
                FirmwareUploadSwiftUI.showUploadUI(alertPublisher: alertPublisher, program: program) {
                    completion?(true)
                    MatrixConnectionViewModel.instance.connect()
                }
            }
        } else {
            program.load { error in
                DispatchQueue.main.async {
                    if error == nil, program.calliopeV1andV2Bin.count != 0 {
                        LogNotify.debug("Successfully finished downloading program")
                        let successAlert = ProgramDownloadSuccessAlert(upload: {
                            DispatchQueue.main.async {
                                FirmwareUploadSwiftUI.uploadWithoutConfirmation(alertPublisher: alertPublisher, program: program) {
                                    completion?(true)
                                }
                            }
                        })
                        alertPublisher.alert = successAlert
                    } else {
                        LogNotify.error("Encountered error during program download: " + (error?.localizedDescription ?? ""))
                        let errorAlert = ProgramDownloadFailedAlert(error: error?.localizedDescription, completion: { completion?(false) })
                        alertPublisher.alert = errorAlert
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
        guard MatrixConnectionViewModel.instance.usageReadyCalliope != nil else {
            LogNotify.error("No calliope connected. Canceling upload.")
            alertPublisher.alert = CannotUploadAlert()
            return
        }
        
        let confirmationAlert = UploadConfirmationAlert(
            name: name,
            upload: {
                DispatchQueue.main.async {
                    uploadWithoutConfirmation(alertPublisher: alertPublisher, program: program, completion: completion)
                }
            }
        )
        alertPublisher.alert = confirmationAlert
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

        let uploader = FirmwareUploadSwiftUI(file: program, alertPublisher: alertPublisher)

        do {
            try uploader.upload(finishedCallback: {
                completion?()
            })
        } catch {
            LogNotify.debug("Upload failed and we are in the catch block")
            FirmwareUploadSwiftUI.uploadingInstance = nil
            UIApplication.shared.isIdleTimerDisabled = false

            let failedAlert = UploadFailedAlert(goToInformation: {
                let informationLink: String = "https://calliope.cc/programmieren/mobil/ipad#hardware"
                if let url = URL(string: informationLink) {
                    UIApplication.shared.open(url)
                }
            })
            alertPublisher.alert = failedAlert
        }
    }

    // NEU: Hilfsmethode für Arcade USB Alert
    private static func showArcadeUSBAlert(alertPublisher: Alertable, completion: (() -> Void)?) {
        let alert = ArcadeUsbRequiredAlert(
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
        alertPublisher.alert = alert
    }

    private var file: Hex
    private var alertPublisher: Alertable

    init(file: Hex, alertPublisher: Alertable) {
        self.file = file
        self.alertPublisher = alertPublisher
    }

    //keep last upload, so it cannot be de-inited prematurely
    private static var uploadingInstance: FirmwareUploadSwiftUI? = nil {
        didSet {
            _ = oldValue?.calliope?.cancelUpload()
        }
    }

    private var finished: () -> Void = {
    }
    private var failed: () -> Void = {
    }

    private var calliope = MatrixConnectionViewModel.instance.usageReadyCalliope

    func upload(finishedCallback: @escaping () -> Void) throws {
        // Validating for the correct Version of the Hex File
        let fileHexTypes = file.getHexTypes()
        LogNotify.log("[FirmwareUpload] File hex types: \(fileHexTypes)")

        guard let calliope else {
            LogNotify.error("No calliope connected. Canceling upload.")
            alertPublisher.alert = CannotUploadAlert()
            return
        }
        LogNotify.log("[FirmwareUpload] Calliope compatible types: \(calliope.compatibleHexTypes)")
        if !calliope.compatibleHexTypes.contains(where: fileHexTypes.contains) {
            LogNotify.log("[FirmwareUpload] ERROR: Hex version mismatch!")
            throw "Unexpected Hex file version"
        }

        FirmwareUploadSwiftUI.uploadingInstance = self

        // WICHTIG: Idle Timer SOFORT deaktivieren, damit der Bildschirm an bleibt
        // Muss VOR beginBackgroundTask() passieren
        UIApplication.shared.isIdleTimerDisabled = true
        LogNotify.log("🔋 Idle timer disabled - screen will stay on during flashing")

        let background_ident = UIApplication.shared.beginBackgroundTask(
            withName: "flashing",
            expirationHandler: { [weak self] () -> Void in
                LogNotify.log("⚠️ Background task expiring - this should not happen during active flashing!")
                LogNotify.log("App should remain in foreground during flashing to prevent iOS from terminating the task")
                // Warnung: Wenn dieser Handler aufgerufen wird, sind nur noch wenige Sekunden Zeit
                // Die App MUSS im Foreground bleiben während des Flashings
            }
        )

        let downloadCompletion = {
            FirmwareUploadSwiftUI.uploadingInstance = nil
            UIApplication.shared.isIdleTimerDisabled = false
            UIApplication.shared.endBackgroundTask(background_ident)
        }

        self.failed = {
            downloadCompletion()
            UploadProgressViewModel.instance.finishUpload()
            MatrixConnectionViewModel.instance.enableDfuMode(mode: false)
        }
        self.finished = {
            downloadCompletion()
            UploadProgressViewModel.instance.finishUpload()
            finishedCallback()
            MatrixConnectionViewModel.instance.enableDfuMode(mode: false)
        }

        do {
            MatrixConnectionViewModel.instance.enableDfuMode(mode: true)

            // USB flashing works by copying a file to the device, so real progress
            // cannot be measured. Show an indeterminate progress instead.
            let isUSB = calliope is USBCalliope
            UploadProgressViewModel.instance.startUpload(
                isIndeterminate: isUSB,
                statusText: isUSB ? NSLocalizedString("Transferring to Calliope", comment: "") : ""
            )
            UploadProgressViewModel.instance.cancelAction = { [weak self] in
                self?.finished()
            }

            // Set up disconnect callback for partial flashing optimization
            if let flashableCalliope = calliope as? FlashableBLECalliope {
                flashableCalliope.requestDisconnectCallback = { [weak self] in
                    LogNotify.log("[PartialFlash] Disconnect requested - triggering immediate disconnect")
                    MatrixConnectionViewModel.instance.connector.disconnectForReboot()
                }
            }

            try calliope.upload(file: file, progressReceiver: self, statusDelegate: self, logReceiver: self)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.showUploadError(error)
            }
        }
    }

    func showUploadError(_ error: Error) {
        LogNotify.error("Upload failed")
        let failedAlert = UploadFailedAlert(goToInformation: {
            let informationLink: String = "https://calliope.cc/programmieren/mobil/ipad#hardware"
            if let url = URL(string: informationLink) {
                UIApplication.shared.open(url)
            }
        })
        alertPublisher.alert = failedAlert
        failed()
    }
}

extension FirmwareUploadSwiftUI: DFUProgressDelegate, DFUServiceDelegate, LoggerDelegate {
    func dfuProgressDidChange(
        for part: Int,
        outOf totalParts: Int,
        to progress: Int,
        currentSpeedBytesPerSecond: Double,
        avgSpeedBytesPerSecond: Double
    ) {
        DispatchQueue.main.async {
            UploadProgressViewModel.instance.updateProgress(Double(progress) / 100.0)
        }
    }

    func logWith(_ level: LogLevel, message: String) {
        LogNotify.log("DFU Message: \(message)")
    }

    func dfuStateDidChange(to state: DFUState) {
        LogNotify.log("DFU State change: \(state)")
        if [DFUState.completed].contains(state) {
            self.finished()
        }
        if [DFUState.aborted].contains(state) {
            // Bei Verbindungswechsel keine Fehlermeldung anzeigen
            if Calliope.isConnectionSwitching {
                LogNotify.log("Connection switching - suppressing abort message")
                return
            }
            self.dfuError(.deviceDisconnected, didOccurWithMessage: "DFU process aborted")
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        LogNotify.log("DFU Error \(error) while uploading: \(message)")

        // Bei Verbindungswechsel keine Fehlermeldung anzeigen
        if Calliope.isConnectionSwitching {
            LogNotify.log("Connection switching - suppressing error message")
            return
        }

        showUploadError(message)
    }
}
