//
//  FirmwareUploadViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import UIKit
import UICircularProgressRing
import iOSDFULibrary

class FirmwareUpload {
    
    public static func showUIForDownloadableProgram(controller: UIViewController, program: DownloadableHexFile, name: String = NSLocalizedString("the program", comment: ""), completion: ((_ success: Bool) -> ())? = nil) {
        if (program.bin.count != 0) {
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
                    let alert: UIAlertController
                    
                    if error == nil, program.bin.count != 0 {
                        let alertDone = UIAlertController(title: NSLocalizedString("Download finished", comment: ""), message: NSLocalizedString("The program is downloaded. Do you want to upload it now?", comment: ""), preferredStyle: .alert)
                        alertDone.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default) { _ in
                            DispatchQueue.main.async {
                                FirmwareUpload.uploadWithoutConfirmation(controller: controller, program: program) {
                                        completion?(true)
                                }
                            }
                        })
                        alertDone.addAction(UIAlertAction(title: NSLocalizedString("No", comment: ""), style: .cancel))
                        alert = alertDone
                    } else {
                        let reason = error?.localizedDescription ?? "The downloaded program is empty"
                        let alertError = UIAlertController(title: NSLocalizedString("Program download failed", comment: ""), message: String(format: NSLocalizedString("The program is not ready. The reason is:\n%@", comment: ""), reason), preferredStyle: .alert)
                        alertError.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
                            completion?(false)
                        })
                        alert = alertError
                    }
                    DispatchQueue.main.async {
                        alertStart.dismiss(animated: true) {
                            controller.present(alert, animated: true)
                        }
                    }
                }
            }
        }
    }

    public static func showUploadUI(controller: UIViewController, program: Hex, name: String = NSLocalizedString("the program", comment: ""), completion: (() -> ())? = nil) {
        let alert = UIAlertController(title: NSLocalizedString("Upload?", comment: ""), message: String(format:NSLocalizedString("Do you want to upload %@ to your calliope?", comment: ""), name), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Upload", comment: ""), style: .default) { _ in
            uploadWithoutConfirmation(controller: controller, program: program, completion: completion)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        controller.present(alert, animated: true)
    }

    public static func uploadWithoutConfirmation(controller: UIViewController, program: Hex, partialFlashing: Bool = true,
                                                 completion: (() -> ())? = nil) {
        let uploader = FirmwareUpload(file: program, controller: controller)
        controller.present(uploader.alertView, animated: true) {
            uploader.upload(finishedCallback: {
                controller.dismiss(animated: true, completion: nil)
                completion?()
            }, partialFlashing: partialFlashing)
        }
    }

    private var file: Hex
    private weak var controller: UIViewController?

    init(file: Hex, controller: UIViewController) {
        self.file = file
        self.controller = controller
    }

	//keep last upload, so it cannot be de-inited prematurely
	private static var uploadingInstance: FirmwareUpload? = nil {
		didSet { _ = oldValue?.calliope?.cancelUpload() }
	}

	lazy var alertView: UIAlertController = {
		guard let calliope = calliope else {
            let alertController = UIAlertController(title: NSLocalizedString("Cannot upload", comment: ""), message: NSLocalizedString("There is no connected calliope in DFU mode", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
            MatrixConnectionViewController.instance.animateBounce()
			return alertController
		}
		
        let uploadController = UIAlertController(title: NSLocalizedString("Uploading", comment: ""), message: "", preferredStyle: .alert)

		let progressView = progressRing
		progressView.translatesAutoresizingMaskIntoConstraints = false
		uploadController.view.addSubview(progressView)


        uploadController.view.addSubview(logTextView)
        let logHeight = 0 //TODO: differenciate debug / production

		uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(withVisualFormat: "V:|-(80)-[progressView(120)]-(8)-[logTextView(logHeight)]-(50)-|", options: [], metrics: ["logHeight": logHeight], views: ["progressView" : progressView, "logTextView": logTextView]))
		uploadController.view.addConstraints(
			NSLayoutConstraint.constraints(withVisualFormat: "H:|-(80@900)-[progressView(120)]-(80@900)-|",
										   options: [], metrics: nil, views: ["progressView" : progressView]))

        uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(withVisualFormat: "H:|-(8@900)-[logTextView(264)]-(8@900)-|",
                                           options: [], metrics: nil, views: ["logTextView": logTextView])
        )

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
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive) {  [weak self] _ in
            self?.finished()
        }
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

	private var finished: () -> () = {}
    private var failed: () -> () = {}

	private var calliope = MatrixConnectionViewController.instance.usageReadyCalliope as? FlashableCalliope

    func upload(finishedCallback: @escaping () -> (), partialFlashing: Bool = true) {
		FirmwareUpload.uploadingInstance = self

        UIApplication.shared.isIdleTimerDisabled = true

        let downloadCompletion = {
            FirmwareUpload.uploadingInstance = nil
            UIApplication.shared.isIdleTimerDisabled = false
        }

        self.failed = downloadCompletion
		self.finished = {
			downloadCompletion()
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
				finishedCallback()
			}
		}

		do {
            try calliope?.upload(file: file, progressReceiver: self, statusDelegate: self, logReceiver: self,
                                 partialFlashing: partialFlashing)
		}
		catch {
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

	deinit {
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
		if progress == 100 {
			self.finished()
		}
	}

    func logWith(_ level: LogLevel, message: String) {
        LogNotify.log("DFU Message: \(message)")
        logTextView.text = message + "\n" + logTextView.text
    }

    func dfuStateDidChange(to state: DFUState) {
        LogNotify.log("DFU State change: \(state)")
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        LogNotify.log("DFU Error \(error) while uploading: \(message)")
        showUploadError(message)
    }
}
