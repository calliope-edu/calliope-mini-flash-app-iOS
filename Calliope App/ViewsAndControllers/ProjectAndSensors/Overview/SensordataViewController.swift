//
//  SensordataPageController.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI
import UICircularProgressRing
import UIKit
import UniformTypeIdentifiers

class SensordataViewController: UIViewController, UIDocumentPickerDelegate {
    var targetUrl: URL?

    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: SensordataView(viewModel: SensordataViewModel(viewController: self)))
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showNewlyCreatedProject" {
            LogNotify.log("Preparing for segue showNewlyCreatedProject")
            guard let destinationVC = segue.destination as? ProjectViewModel else {
                return
            }
            destinationVC.project = Project.fetchProject(id: sender as! Int)!
        }
    }
    
    @IBSegueAction func initializeDataLoggerViewModel(_ coder: NSCoder) -> DataLoggerViewModel? {
        LogNotify.debug("Setting up DataLogger ViewModel")
        let dataLoggerViewModel = DataLoggerViewModel(coder: coder)

        if !MatrixConnectionViewController.instance.isInUsbMode,
            let result = (MatrixConnectionViewController.instance.usageReadyCalliope as? CalliopeAPI)?.currentJob?.result, dataLoggerViewModel != nil
        {
            dataLoggerViewModel!.htmlData = result
            return dataLoggerViewModel
        }

        if MatrixConnectionViewController.instance.isInUsbMode, let url = targetUrl, dataLoggerViewModel != nil {
            dataLoggerViewModel!.htmlData = try! url.asData()
            return dataLoggerViewModel
        }

        LogNotify.error("No data")
        return nil
    }
    
    @IBSegueAction func initializeEditorView(_ coder: NSCoder) -> EditorViewController? {
        let editor = MakeCode()
        editor.url = targetUrl
        return EditorViewController(coder: coder, editor: editor)
    }

    func createNewProject() {
        LogNotify.log("Starting to create a new Project")
        let alertController = UIAlertController(
            title: NSLocalizedString("Enter an Projectname for the new Project", comment: ""),
            message: nil,
            preferredStyle: .alert
        )
        alertController.addTextField { (textField) in
            textField.placeholder = "Calliope Project"
        }

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let name = textField.text {
                let normalizedName = name.isEmpty ? "Calliope Project" : name
                let project = Project.insertProject(name: normalizedName)
                self.performSegue(withIdentifier: "showNewlyCreatedProject", sender: project?.id)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }

    func openProject(project: Project) {
        performSegue(withIdentifier: "showNewlyCreatedProject", sender: project.id)
    }

    func getDataloggerHtml(connectedCalliope: Calliope, isUsbMode: Bool) {
        if isUsbMode {
            getDataLoggerHTMLFrom(usbCalliope: connectedCalliope)
            return
        }
        getDataLoggerHTMLFrom(bleCalliope: connectedCalliope)

    }

    func getDataLoggerHTMLFrom(usbCalliope calliope: Calliope) {
        DispatchQueue.main.async {
            let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "htm")!])
            documentPickerController.delegate = self
            self.present(documentPickerController, animated: true, completion: nil)
        }
    }

    private func getDataLoggerHTMLFrom(bleCalliope calliope: Calliope) {
        guard let calliope = (calliope as? CalliopeAPI) else {
            return
        }

        progressRing.resetProgress()
        self.present(alertView, animated: true)
        calliope.startUtilityJob(
            for: .LOG_HTML,
            onProgress: { [self] (a) in progressRing.startProgress(to: CGFloat(a), duration: 0.2) },
            onCompletion: {
                self.dismiss(animated: true)
                self.performSegue(withIdentifier: "showDataLoggerHTML", sender: self)
            },
            onFailure: {
                self.dismiss(animated: true)

                let failureReason = calliope.currentJob?.jobState
                if failureReason == .Canceled {
                    return
                }

                let alert = UIAlertController(
                    title: NSLocalizedString("Datalogger Download Failed!", comment: ""),
                    message: String(
                        format: NSLocalizedString(
                            "There was an issue downloading the datalogger data from your Calliope mini. Please ensure you are connected to the Calliope and try again.",
                            comment: ""
                        )
                    ),
                    preferredStyle: .alert
                )
                alert.addAction(
                    UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                        self.dismiss(animated: true)
                    }
                )
                self.present(alert, animated: true)
            }
        )
    }
    
    // UI Components for displaying Datalogger Loading
    private lazy var alertView: UIAlertController = {
        let uploadController = UIAlertController(
            title: NSLocalizedString("Transfering Datalogger Data", comment: ""),
            message: "",
            preferredStyle: .alert
        )

        let progressView: UIView
        let logHeight = 0

        progressView = progressRing
        progressView.translatesAutoresizingMaskIntoConstraints = false

        uploadController.view.addSubview(progressView)
        uploadController.view.addSubview(logTextView)
        uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "V:|-(80)-[progressView(120)]-(8)-[logTextView(logHeight)]-(80)-|",
                options: [],
                metrics: ["logHeight": logHeight],
                views: ["progressView": progressView, "logTextView": logTextView]
            )
        )
        progressView.widthAnchor.constraint(equalToConstant: 120).isActive = true
        progressView.centerXAnchor.constraint(equalTo: uploadController.view.centerXAnchor).isActive = true

        uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(8@900)-[logTextView(264)]-(8@900)-|",
                options: [],
                metrics: nil,
                views: ["logTextView": logTextView]
            )
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
        ring.valueFormatter = UICircularProgressRingFormatter(valueIndicator: "%", rightToLeft: false, showFloatingPoint: false, decimalPlaces: 0)
        return ring
    }()

    private lazy var cancelUploadAction: UIAlertAction = {
        UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive) { [weak self] _ in
            guard let connectedCalliope = (MatrixConnectionViewController.instance.usageReadyCalliope as? CalliopeAPI) else {
                return
            }
            connectedCalliope.cancelUtilityJob()
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

    func openBluetoothSensorInfoWebView() {
        self.targetUrl = URL.init(string: "https://makecode.calliope.cc/#pub:_30A13o6dM9L2")
        self.performSegue(withIdentifier: "showEditor", sender: self)
    }

    func openDataLoggerInfoWebView() {
        self.targetUrl = URL.init(string: "https://makecode.calliope.cc/#pub:_Dv9J1xCp6HRy")
        self.performSegue(withIdentifier: "showEditor", sender: self)
    }
}
