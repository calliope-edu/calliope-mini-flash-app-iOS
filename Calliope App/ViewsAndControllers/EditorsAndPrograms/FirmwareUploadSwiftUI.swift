//
//  FirmwareUploadViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import NordicDFU
import UICircularProgressRing
import UIKit

class FirmwareUploadSwiftUI {

    public static func showUIForDownloadableProgram(
        controller: UIViewController,
        program: DownloadableHexFile,
        name: String = NSLocalizedString("the program", comment: ""),
        completion: ((_ success: Bool) -> Void)? = nil
    ) {
        /* if program.calliopeV1andV2Bin.count != 0 {
             DispatchQueue.main.async {
                 FirmwareUpload.showUploadUI(controller: controller, program: program) {
                     completion?(true)
                     MatrixConnectionViewModel.instance.connect()
                 }
             }
         } else {
             let alertStart = UIAlertController(title: NSLocalizedString("Wait a little", comment: ""), message: NSLocalizedString("The program is being downloaded. Please wait a little.", comment: ""), preferredStyle: .alert)
             alertStart.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))

             controller.present(alertStart, animated: true) {
                 program.load { error in
                     DispatchQueue.main.async {
                         let alert: UIAlertController

                         if error == nil, program.calliopeV1andV2Bin.count != 0 {
                             let alertDone = UIAlertController(title: NSLocalizedString("Download finished", comment: ""), message: NSLocalizedString("The program is downloaded. Do you want to upload it now?", comment: ""), preferredStyle: .alert)
                             alertDone.addAction(
                                 UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default) { _ in
                                     FirmwareUpload.uploadWithoutConfirmation(controller: controller, program: program) {
                                         completion?(true)
                                     }
                                 })
                             alertDone.addAction(UIAlertAction(title: NSLocalizedString("No", comment: ""), style: .cancel))
                             alert = alertDone
                         } else {
                             let reason = error?.localizedDescription ?? "The downloaded program is empty"
                             let alertError = UIAlertController(title: NSLocalizedString("Program download failed", comment: ""), message: String(format: NSLocalizedString("The program is not ready. The reason is:\n%@", comment: ""), reason), preferredStyle: .alert)
                             alertError.addAction(
                                 UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
                                     completion?(false)
                                 })
                             alert = alertError
                         }

                         alertStart.dismiss(animated: true) {
                             controller.present(alert, animated: true)
                         }
                     }
                 }
             }
         }*/
    }

    public static func showUploadUI(
        program: Hex,
        name: String = NSLocalizedString("the program", comment: ""),
        completion: (() -> Void)? = nil
    ) {
        let popup = TwoOptionsAlert(
            title: NSLocalizedString("Upload?", comment: ""),
            message: String(format: NSLocalizedString("Do you want to upload %@ to your Calliope mini?", comment: ""), name),
            actions: [
                AlertAction(
                    title: "Upload",
                    action: {
                        DispatchQueue.main.async {
                            uploadWithoutConfirmation(program: program, completion: completion)
                        }
                    }
                ),
                AlertAction(title: "Cancel", action: {}),
            ]
        )
        DispatchQueue.main.async {
            PopupManager.instance.show(.alert(popup))
        }
    }

    @MainActor public static func uploadWithoutConfirmation(
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
                showArcadeUSBAlert(completion: completion)
                return
            }
        }

        let uploader = FirmwareUploadSwiftUI(file: program)
        let tempCalliope = MatrixConnectionViewModel.instance.usageReadyCalliope

        PopupManager.instance.show(uploader.alertView)

        do {
            try uploader.upload(finishedCallback: {
                PopupManager.instance.dismiss(id: uploader.alertView.id)
                completion?()
            })
        } catch {
            LogNotify.debug("Upload failed and we are in the catch block")
            FirmwareUploadSwiftUI.uploadingInstance = nil
            UIApplication.shared.isIdleTimerDisabled = false

            let popup = TwoOptionsAlert(
                title: NSLocalizedString("Upload failed", comment: ""),
                message: String(
                    format: NSLocalizedString(
                        "The program does not seem to match the version of your Calliope mini. Please check the hardware selection in your editor again.",
                        comment: ""
                    )
                ),
                actions: [
                    AlertAction(
                        title: "Cancel",
                        action: {
                            PopupManager.instance.dismiss(id: uploader.alertView.id)
                        }
                    ),
                    AlertAction(
                        title: "Futher Information",
                        action: {
                            let informationLink: String = "https://calliope.cc/programmieren/mobil/ipad#hardware"
                            if let url = URL(string: informationLink) {
                                UIApplication.shared.open(url)
                            }
                            PopupManager.instance.dismiss(id: uploader.alertView.id)
                        }
                    ),
                ]
            )
            PopupManager.instance.show(.alert(popup))
        }
    }

    // NEU: Hilfsmethode für Arcade USB Alert
    private static func showArcadeUSBAlert(completion: (() -> Void)?) {
        /*let alert = UIAlertController(
            title: NSLocalizedString("USB-Verbindung erforderlich", comment: "USB connection required"),
            message: NSLocalizedString(
                "Arcade-Programme können nur per USB auf den Calliope mini übertragen werden.\n\nBitte verbinde den Calliope mini per USB-Kabel und wähle den MINI-Ordner aus.",
                comment: "Arcade programs can only be transferred via USB"
            ),
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: NSLocalizedString("USB-Modus öffnen", comment: "Open USB mode"),
                style: .default
            ) { _ in
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
            }
        )

        alert.addAction(
            UIAlertAction(
                title: NSLocalizedString("Abbrechen", comment: "Cancel"),
                style: .cancel
            ) { _ in
                completion?()
            }
        )

        controller.present(alert, animated: true)*/
    }

    private var file: Hex

    init(file: Hex) {
        self.file = file
    }

    //keep last upload, so it cannot be de-inited prematurely
    private static var uploadingInstance: FirmwareUploadSwiftUI? = nil {
        didSet {
            _ = oldValue?.calliope?.cancelUpload()
        }
    }

    lazy var alertView: Popup = {
        .progress(ProgressPopup(title: "Transmission running", onCancel: {}))
        /*guard let calliope = calliope else {
            let alertController = UIAlertController(
                title: NSLocalizedString("Cannot upload", comment: "Übertragung nicht möglich"),
                message: NSLocalizedString(
                    "There is no connected Calliope mini in DFU mode",
                    comment: "Es konnte kein Calliope mini gefunden werden"
                ),
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
            MatrixConnectionViewModel.instance.animateBounce()
            return alertController
        }

        let uploadController = UIAlertController(title: NSLocalizedString("Transmission running", comment: ""), message: "", preferredStyle: .alert)

        let progressView: UIView
        let logHeight = 0

        if calliope is USBCalliope {
            uploadController.message = NSLocalizedString("Calliope mini will start the program as soon as the transmission is complete.", comment: "")

            // Container für Spinner + Timer
            let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false

            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            activityIndicator.startAnimating()

            containerView.addSubview(activityIndicator)
            containerView.addSubview(usbTimerLabel)

            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),

                usbTimerLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                usbTimerLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 30),
                usbTimerLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            ])

            // Statische Nachricht anzeigen (kein Timer wegen Blocking-Operationen)
            usbTimerLabel.text = NSLocalizedString("Duration: about 10 seconds", comment: "USB transfer duration message")

            progressView = containerView
        } else {
            progressView = progressRing
        }
        progressView.translatesAutoresizingMaskIntoConstraints = false

        uploadController.view.addSubview(progressView)
        uploadController.view.addSubview(logTextView)

        // BLE uses smaller top margin and larger bottom margin for taller alert
        let topMargin = (calliope is USBCalliope) ? 80 : 60
        let bottomMargin = (calliope is USBCalliope) ? 50 : 80

        // Vertical constraints for progressView and logTextView
        uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "V:|-(topMargin)-[progressView(120)]-(8)-[logTextView(logHeight)]-(bottomMargin)-|",
                options: [],
                metrics: ["topMargin": topMargin, "logHeight": logHeight, "bottomMargin": bottomMargin],
                views: ["progressView": progressView, "logTextView": logTextView]
            )
        )

        // Center progressView horizontally with fixed width
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: uploadController.view.centerXAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 120),
        ])

        // Center logTextView horizontally with fixed width
        NSLayoutConstraint.activate([
            logTextView.centerXAnchor.constraint(equalTo: uploadController.view.centerXAnchor),
            logTextView.widthAnchor.constraint(equalToConstant: 264),
        ])

        uploadController.addAction(cancelUploadAction)
        return uploadController*/
    }()

    private lazy var progressRing: UICircularProgressRing = {
        let ring = UICircularProgressRing()
        ring.minValue = 0
        ring.maxValue = 100
        ring.style = UICircularRingStyle.ontop
        ring.outerRingColor = #colorLiteral(red: 0.976000011, green: 0.7760000229, blue: 0.1490000039, alpha: 1)
        ring.innerRingColor = #colorLiteral(red: 0.2980000079, green: 0.851000011, blue: 0.3919999897, alpha: 1)
        ring.shouldShowValueText = true
        //ring.gradientOptions = UICircularRingGradientOptions(startPosition: .top, endPosition: .top, colors: [#colorLiteral(red: 0.2469999939, green: 0.7839999795, blue: 0.3880000114, alpha: 1), #colorLiteral(red: 0.2980000079, green: 0.851000011, blue: 0.3919999897, alpha: 1)], colorLocations: [0.0, 100.0])
        ring.valueFormatter = UICircularProgressRingFormatter(valueIndicator: "%", rightToLeft: false, showFloatingPoint: false, decimalPlaces: 0)
        return ring
    }()

    private lazy var cancelUploadAction: UIAlertAction = {
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive) { [weak self] _ in
            self?.finished()
        }
    }()
    private var usbTimer: Timer?
    private var usbStartTime: Date?

    private lazy var usbTimerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        label.textColor = .gray
        return label
    }()
    private lazy var logTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.clipsToBounds = true
        return textView
    }()

    private var finished: () -> Void = {
    }
    private var failed: () -> Void = {
    }

    private var calliope = MatrixConnectionViewModel.instance.usageReadyCalliope

    func upload(finishedCallback: @escaping () -> Void) throws {
        // Timer deaktiviert - USB-Kopieren blockiert Main-Thread, daher zeigen wir statisch "~15 Sekunden"
        // if MatrixConnectionViewModel.instance.usageReadyCalliope is USBCalliope {
        //     startUSBTimer()
        // }

        // Validating for the correct Version of the Hex File
        let fileHexTypes = file.getHexTypes()
        LogNotify.log("[FirmwareUpload] File hex types: \(fileHexTypes)")

        guard let calliope else {
            LogNotify.error("No calliope connected. Canceling upload.")
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
            // self.stopUSBTimer() // Timer deaktiviert
            MatrixConnectionViewModel.instance.enableDfuMode(mode: false)
        }
        self.finished = {
            downloadCompletion()
            // self.stopUSBTimer() // Timer deaktiviert
            finishedCallback()
            MatrixConnectionViewModel.instance.enableDfuMode(mode: false)
        }

        do {
            MatrixConnectionViewModel.instance.enableDfuMode(mode: true)

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
        /*alertView.title = NSLocalizedString("Upload failed!", comment: "")
        // Don't set alertView.message to prevent overlap with progress ring
        // Instead show error in logTextView
        logTextView.text = error.localizedDescription
        // Don't change ring color to red - keep original color

        // Re-enable cancel button so user can dismiss the alert
        cancelUploadAction.isEnabled = true

        failed()*/
    }

    /* Usage above is commented out. Why do we need this?
     func startUSBTimer() {
        LogNotify.log("⏱️ USB Timer starting now")
        usbStartTime = Date()
        usbTimerLabel.text = "00:00 / 15 " + NSLocalizedString("seconds", comment: "")

        usbTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.updateUSBTimerLabel()
        }
        LogNotify.log("⏱️ USB Timer scheduled")
    }

    private func updateUSBTimerLabel() {
        guard let startTime = usbStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)

        // Log first update
        if elapsed < 0.1 {
            LogNotify.log("⏱️ USB Timer first update: \(elapsed)s")
        }

        // Timer bei 15 Sekunden stoppen
        if elapsed >= 15.0 {
            let timeString = String(format: "15:00 / 15 %@", NSLocalizedString("seconds", comment: ""))
            self.usbTimerLabel.text = timeString
            stopUSBTimer()
            return
        }

        let seconds = Int(elapsed)
        let hundredths = Int((elapsed - Double(seconds)) * 100)

        let timeString = String(format: "%02d:%02d / 15 %@", seconds, hundredths, NSLocalizedString("seconds", comment: ""))

        // Update label directly (we're already on main thread since timer is on main runloop)
        self.usbTimerLabel.text = timeString
    }

    private func stopUSBTimer() {
        usbTimer?.invalidate()
        usbTimer = nil
        usbStartTime = nil
    }*/

    deinit {
        // stopUSBTimer() // Timer deaktiviert
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.progressRing.startProgress(to: CGFloat(progress), duration: 0.2)
            PopupManager.instance.updateProgress(id: alertView.id, progress: Double(progress) / 100)
            if progress > 0 && self.cancelUploadAction.isEnabled {
                self.cancelUploadAction.isEnabled = false
                let failed = self.failed
                self.failed = {
                    self.cancelUploadAction.isEnabled = true
                    failed()
                }
            }
        }
    }

    func logWith(_ level: LogLevel, message: String) {
        LogNotify.log("DFU Message: \(message)")
        logTextView.text = message + "\n" + logTextView.text
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
