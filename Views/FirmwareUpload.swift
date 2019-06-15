//
//  FirmwareUploadViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import UIKit
import iOSDFULibrary

class FirmwareUpload {

	//keep last upload, so it cannot be de-inited prematurely
	private static var uploadingInstance: FirmwareUpload? = nil

	lazy var alertView: UIAlertController = {
		guard let calliope = calliope else {
			let alertController = UIAlertController(title: "Cannot upload", message: "There is no connected calliope in DFU mode", preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
			return alertController
		}
		let uploadController = UIAlertController(title: "Uploading", message: "Starting upload...", preferredStyle: .alert)

		uploadController.view.addSubview(progressBar)
		uploadController.view.addConstraints(
			[NSLayoutConstraint.constraints(withVisualFormat: "H:|-(8)-[bar]-(8)-|",
											options: [], metrics: nil, views: ["bar" : progressBar]),
			 NSLayoutConstraint.constraints(withVisualFormat: "V:|-(8)-[bar(2)]-(8)-|",
											options: [], metrics: nil, views: ["bar" : progressBar])]
				.flatMap({ $0 })
		)
		uploadController.addAction(UIAlertAction(title: "Cancel", style: .destructive) { _ in
			_ = self.calliope?.cancelUpload()
			self.finished()
		})
		return uploadController
	}()


	private lazy var progressBar: UIProgressView = {
		let bar = UIProgressView()
		bar.translatesAutoresizingMaskIntoConstraints = false
		bar.setProgress(0.0, animated: false)
		return bar
	}()

	private var finished: () -> () = {}

	private var calliope = MatrixConnectionViewController.instance.usageReadyCalliope as? DFUCalliope

	func upload(file: HexFile, finished: @escaping () -> ()) {
		_ = FirmwareUpload.uploadingInstance?.calliope?.cancelUpload()
		FirmwareUpload.uploadingInstance = self

		self.finished = {
			FirmwareUpload.uploadingInstance = nil
			MatrixConnectionViewController.instance.connect()
			finished()
		}
		let bin = file.bin()
		do {
			try calliope?.upload(bin: bin, dat: HexFile.dat(bin), progressReceiver: self)
		}
		catch {
			DispatchQueue.main.async {
				self.alertView.title = "Upload failed!"
				self.alertView.message = "\(error.localizedDescription)"
				self.finished()
			}
		}
	}

	deinit {
		NSLog("deinited FirmwareUpload")
	}
}

extension FirmwareUpload: DFUProgressDelegate {
	func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
		if progress < 100 {
			DispatchQueue.main.async {
				self.progressBar.setProgress(Float(progress) / 100.0, animated: true)
				self.alertView.message = "uploaded \(progress)%"
				self.alertView.view.layoutIfNeeded()
			}
		} else {
			self.finished()
		}
	}
}
