//
//  FirmwareUploadViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import NordicDFU
import UICircularProgressRing
import UIKit

class FirmwareUpload {

    public static func showUIForDownloadableProgram(controller: UIViewController, program: DownloadableHexFile, name: String = NSLocalizedString("the program", comment: ""), completion: ((_ success: Bool) -> Void)? = nil) {
        if program.calliopeV1andV2Bin.count != 0 {
            DispatchQueue.main.async {
                FirmwareUpload.showUploadUI(controller: controller, program: program) {
                    completion?(true)
                    MatrixConnectionViewController.instance.connect()
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
        }
    }

    public static func showUploadUI(controller: UIViewController, program: Hex, name: String = NSLocalizedString("the program", comment: ""), completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: NSLocalizedString("Upload?", comment: ""), message: String(format: NSLocalizedString("Do you want to upload %@ to your Calliope mini?", comment: ""), name), preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: NSLocalizedString("Upload", comment: ""), style: .default) { _ in
                uploadWithoutConfirmation(controller: controller, program: program, completion: completion)
            })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        controller.present(alert, animated: true)
    }

    public static func uploadWithoutConfirmation(
        controller: UIViewController, program: Hex,
        completion: (() -> Void)? = nil
    ) {
        // NEU: Prüfe ob es eine Arcade-Datei ist
        let hexTypes = program.getHexTypes()
        if hexTypes.contains(.arcade) {
            // Arcade-Dateien können nur per USB übertragen werden
            // Prüfe zuerst ob bereits eine USB-Verbindung besteht
            if let matrixVC = MatrixConnectionViewController.instance,
               matrixVC.isUSBConnected() {
                // USB ist bereits verbunden, fahre mit Upload fort
                // (Der Code fällt durch zu uploadAlert unten)
            } else {
                // Keine USB-Verbindung, zeige Alert
                showArcadeUSBAlert(controller: controller, completion: completion)
                return
            }
        }
        
        let informationLink: String = "https://calliope.cc/programmieren/mobil/ipad#hardware"

        let uploader = FirmwareUpload(file: program, controller: controller)
        let tempCalliope = MatrixConnectionViewController.instance.usageReadyCalliope

        controller.present(uploader.alertView, animated: true) {
            do {
                try uploader.upload(finishedCallback: {
                    controller.dismiss(animated: true, completion: nil)
                    completion?()
                })
            } catch {
                FirmwareUpload.uploadingInstance = nil
                UIApplication.shared.isIdleTimerDisabled = false

                let alert = UIAlertController(
                    title: NSLocalizedString("Upload failed", comment: ""),
                    message: String(format: NSLocalizedString("The program does not seem to match the version of your Calliope mini. Please check the hardware selection in your editor again.", comment: "")),
                    preferredStyle: .alert
                )
                alert.addAction(
                    UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                        uploader.alertView.dismiss(animated: true)
                    })
                alert.addAction(
                    UIAlertAction(title: NSLocalizedString("Further Information", comment: ""), style: .default) { _ in
                        if let url = URL(string: informationLink) {
                            UIApplication.shared.open(url)
                        }
                        uploader.alertView.dismiss(animated: true)
                    })
                uploader.alertView.present(alert, animated: true)
            }
        }
    }

    // NEU: Hilfsmethode für Arcade USB Alert
    private static func showArcadeUSBAlert(controller: UIViewController, completion: (() -> Void)?) {
        let alert = UIAlertController(
            title: NSLocalizedString("USB-Verbindung erforderlich", comment: "USB connection required"),
            message: NSLocalizedString("Arcade-Programme können nur per USB auf den Calliope mini übertragen werden.\n\nBitte verbinde den Calliope mini per USB-Kabel und wähle den MINI-Ordner aus.", comment: "Arcade programs can only be transferred via USB"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("USB-Modus öffnen", comment: "Open USB mode"),
            style: .default
        ) { _ in
            // Wechsle in USB-Modus
            if let matrixVC = MatrixConnectionViewController.instance {
                // Expand the matrix connection view if it's collapsed
                if matrixVC.collapseButton.expansionState != .open {
                    matrixVC.animate(expand: true)
                }

                // Switch to USB mode (this triggers switchChanged which updates the UI)
                matrixVC.usbSwitch.isOn = true
                matrixVC.switchChanged(usbSwitch: matrixVC.usbSwitch)

                // Open the file picker after a short delay to allow the UI to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    matrixVC.startUSBconnect(matrixVC.connectButton as Any)
                }
            }
            completion?()
        })
        
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Abbrechen", comment: "Cancel"),
            style: .cancel
        ) { _ in
            completion?()
        })
        
        controller.present(alert, animated: true)
    }

    private var file: Hex
    private weak var controller: UIViewController?

    init(file: Hex, controller: UIViewController) {
        self.file = file
        self.controller = controller
    }

    //keep last upload, so it cannot be de-inited prematurely
    private static var uploadingInstance: FirmwareUpload? = nil {
        didSet {
            _ = oldValue?.calliope?.cancelUpload()
        }
    }

    lazy var alertView: UIAlertController = {
        guard let calliope = calliope else {
            let alertController = UIAlertController(title: NSLocalizedString("Cannot upload", comment: "Übertragung nicht möglich"), message: NSLocalizedString("There is no connected Calliope mini in DFU mode", comment: "Es konnte kein Calliope mini gefunden werden"), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
            MatrixConnectionViewController.instance.animateBounce()
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
                usbTimerLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
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

        // Vertical constraints for progressView and logTextView
        uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(withVisualFormat: "V:|-(80)-[progressView(120)]-(8)-[logTextView(logHeight)]-(50)-|", options: [], metrics: ["logHeight": logHeight], views: ["progressView": progressView, "logTextView": logTextView]))

        // Center progressView horizontally with fixed width
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: uploadController.view.centerXAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 120)
        ])

        // Center logTextView horizontally with fixed width
        NSLayoutConstraint.activate([
            logTextView.centerXAnchor.constraint(equalTo: uploadController.view.centerXAnchor),
            logTextView.widthAnchor.constraint(equalToConstant: 264)
        ])

        uploadController.addAction(cancelUploadAction)
        return uploadController
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

    private var calliope = MatrixConnectionViewController.instance.usageReadyCalliope

    func upload(finishedCallback: @escaping () -> Void) throws {
        // Timer deaktiviert - USB-Kopieren blockiert Main-Thread, daher zeigen wir statisch "~15 Sekunden"
        // if MatrixConnectionViewController.instance.usageReadyCalliope is USBCalliope {
        //     startUSBTimer()
        // }

        // Validating for the correct Version of the Hex File
        let fileHexTypes = file.getHexTypes()
        LogNotify.log("[FirmwareUpload] File hex types: \(fileHexTypes)")

        guard let calliope else {
            return
        }
        LogNotify.log("[FirmwareUpload] Calliope compatible types: \(calliope.compatibleHexTypes)")
        if !calliope.compatibleHexTypes.contains(where: fileHexTypes.contains) {
            LogNotify.log("[FirmwareUpload] ERROR: Hex version mismatch!")
            throw "Unexpected Hex file version"
        }

        FirmwareUpload.uploadingInstance = self

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
            })

        let downloadCompletion = {
            FirmwareUpload.uploadingInstance = nil
            UIApplication.shared.isIdleTimerDisabled = false
            UIApplication.shared.endBackgroundTask(background_ident)
        }

        self.failed = {
            downloadCompletion()
            // self.stopUSBTimer() // Timer deaktiviert
            MatrixConnectionViewController.instance.enableDfuMode(mode: false)
        }
        self.finished = {
            downloadCompletion()
            // self.stopUSBTimer() // Timer deaktiviert
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
                finishedCallback()
            }
            MatrixConnectionViewController.instance.enableDfuMode(mode: false)
        }

        do {
            MatrixConnectionViewController.instance.enableDfuMode(mode: true)
            try calliope.upload(file: file, progressReceiver: self, statusDelegate: self, logReceiver: self)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.showUploadError(error)
            }
        }
    }

    func showUploadError(_ error: Error) {
        alertView.title = NSLocalizedString("Upload failed!", comment: "")
        alertView.message = "\(error.localizedDescription)"
        progressRing.outerRingColor = #colorLiteral(red: 0.99, green: 0.29, blue: 0.15, alpha: 1)
        failed()
    }
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
    }
    deinit {
        // stopUSBTimer() // Timer deaktiviert
        NSLog("FirmwareUpload deinited")
    }
}

extension FirmwareUpload: DFUProgressDelegate, DFUServiceDelegate, LoggerDelegate {
    func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.progressRing.startProgress(to: CGFloat(progress), duration: 0.2)
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
