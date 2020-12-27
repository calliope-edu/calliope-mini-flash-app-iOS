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
    
    public static func showUIForDownloadableProgram(controller: UIViewController, program: DownloadableHexFile, name: String = "the program".localized, completion: (() -> ())? = nil) {
        if (program.bin.count != 0) {
            FirmwareUpload.showUploadUI(controller: controller, program: program) {
                MatrixConnectionViewController.instance.connect()
            }
        } else {
            let alertStart = UIAlertController(title: "Wait a little".localized, message: "The program is being downloaded. Please wait a little.".localized, preferredStyle: .alert)
            alertStart.addAction(UIAlertAction(title: "Ok", style: .default))
            
            controller.present(alertStart, animated: true) {
                program.load { error in
                    let alert: UIAlertController
                    
                    if error == nil {
                        let alertDone = UIAlertController(title: "Download finished".localized, message: "The program is downloaded. Do you want to upload it now?".localized, preferredStyle: .alert)
                        alertDone.addAction(UIAlertAction(title: "Yes".localized, style: .default) { _ in
                            self.showUIForDownloadableProgram(controller: controller, program: program)
                        })
                        alertDone.addAction(UIAlertAction(title: "No".localized, style: .cancel))
                        alert = alertDone
                    } else {
                        let alertError = UIAlertController(title: "Program download failed".localized, message: String(format: "The program is not ready. The reason is\n%s".localized, "\(error!.localizedDescription)"), preferredStyle: .alert)
                        alertError.addAction(UIAlertAction(title: "Ok", style: .default))
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

    public static func showUploadUI(controller: UIViewController, program: Hex, name: String = "the program".localized, completion: (() -> ())? = nil) {
        let alert = UIAlertController(title: "Upload?".localized, message: String(format:"Do you want to upload %s to your calliope?".localized, name), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Upload".localized, style: .default) { _ in
            let uploader = FirmwareUpload()
            controller.present(uploader.alertView, animated: true) {
                uploader.upload(file: program) {
                    controller.dismiss(animated: true, completion: nil)
                    completion?()
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        controller.present(alert, animated: true)
    }
    
	//keep last upload, so it cannot be de-inited prematurely
	private static var uploadingInstance: FirmwareUpload? = nil {
		didSet { _ = oldValue?.calliope?.cancelUpload() }
	}

	lazy var alertView: UIAlertController = {
		guard let calliope = calliope else {
            let alertController = UIAlertController(title: "Cannot upload".localized, message: "There is no connected calliope in DFU mode".localized, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: nil))
            MatrixConnectionViewController.instance.animateBounce()
			return alertController
		}
		
        let uploadController = UIAlertController(title: "Uploading".localized, message: "", preferredStyle: .alert)

		let progressView = progressRing
		progressView.translatesAutoresizingMaskIntoConstraints = false

		uploadController.view.addSubview(progressView)
		uploadController.view.addConstraints(
			 NSLayoutConstraint.constraints(withVisualFormat: "V:|-(80)-[bar(120)]-(80)-|",
											options: [], metrics: nil, views: ["bar" : progressView]))
		uploadController.view.addConstraints(
			NSLayoutConstraint.constraints(withVisualFormat: "H:|-(80@900)-[bar(120)]-(80@900)-|",
										   options: [], metrics: nil, views: ["bar" : progressView]))
        uploadController.addAction(UIAlertAction(title: "Cancel".localized, style: .destructive) {  [weak self] _ in
			self?.finished()
		})
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

	private var finished: () -> () = {}
	private var failed: () -> () = {
		FirmwareUpload.uploadingInstance = nil
	}

	private var calliope = MatrixConnectionViewController.instance.usageReadyCalliope as? DFUCalliope

	func upload(file: Hex, finished: @escaping () -> ()) {
		FirmwareUpload.uploadingInstance = self

		self.finished = {
			FirmwareUpload.uploadingInstance = nil
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
				finished()
			}
		}

		let bin = file.bin
		do {
			try calliope?.upload(bin: bin, dat: HexFile.dat(bin), progressReceiver: self)
		}
		catch {
			DispatchQueue.main.async { [weak self] in
                self?.alertView.title = "Upload failed!".localized
				self?.alertView.message = "\(error.localizedDescription)"
				self?.progressRing.isHidden = true
				self?.failed()
			}
		}
	}

	deinit {
		NSLog("FirmwareUpload deinited")
	}
}

extension FirmwareUpload: DFUProgressDelegate {
	func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
		DispatchQueue.main.async { [weak self] in
			self?.progressRing.startProgress(to: CGFloat(progress), duration: 0.2)
		}
		if progress == 100 {
			self.finished()
		}
	}
}
