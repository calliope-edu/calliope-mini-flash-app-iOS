//
//  ProjectOverviewController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import CoreServices
import SwiftUI
import UICircularProgressRing
import UIKit

class ProjectOverviewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {

    @IBOutlet weak var stackView: UIStackView?
    @IBOutlet weak var addProjectButton: UIButton!
    @IBOutlet weak var projectContainerView: UIView?

    @IBOutlet weak var dataloggerInformationButton: UIButton!

    @objc var projectCollectionViewController: ProjectCollectionViewController?

    @objc var dataLoggerViewController: DataLoggerViewController?

    var projectHeightConstraint: NSLayoutConstraint?
    var projectKvo: Any?

    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!

    private var connectedCalliope: CalliopeAPI?

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(
            alongsideTransition: { (_) in
                self.configureLayout(size)
            },
            completion: { _ in
                self.projectCollectionViewController?.collectionView.reloadData()
            })
    }

    private func configureLayout(_ size: CGSize) {
        let landscape = size.width > size.height
        stackView?.distribution = landscape ? .fillEqually : .fill
        stackView?.alignment = landscape ? .top : .fill
        stackView?.axis = landscape ? .horizontal : .vertical
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addProjectButton.setTitle("", for: .normal)
        projectContainerView?.translatesAutoresizingMaskIntoConstraints = false
        projectHeightConstraint = projectContainerView?.heightAnchor.constraint(equalToConstant: 10)
        projectHeightConstraint?.isActive = true

        addNotificationSubscriptions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        projectKvo = observe(\.projectCollectionViewController?.collectionView.contentSize) { (containerVC, _) in
            containerVC.projectHeightConstraint!.constant = containerVC.projectCollectionViewController!.collectionView.contentSize.height
            containerVC.projectCollectionViewController?.collectionView.layoutIfNeeded()
        }

        MatrixConnectionViewController.instance?.connectionDescriptionText = NSLocalizedString("Calliope mini verbinden!", comment: "")
        MatrixConnectionViewController.instance?.calliopeClass = DiscoveredBLEDDevice.self

        self.connectedCalliope = MatrixConnectionViewController.instance.usageReadyCalliope as? CalliopeAPI
        dataloggerInformationButton.isEnabled = connectedCalliope?.discoveredOptionalServices.contains(.microbitUtilityService) ?? false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        projectKvo = nil
    }

    @IBSegueAction func initializeDataLoggerWebView(_ coder: NSCoder) -> DataLoggerViewController? {
        LogNotify.log("Setting up DataLogger ViewController")
        guard let result = self.connectedCalliope?.currentJob?.result else {
            LogNotify.log("Missing Result Data, Aborting")
            return nil
        }

        self.dataLoggerViewController = DataLoggerViewController(coder: coder)
        self.dataLoggerViewController?.htmlData = result
        return dataLoggerViewController
    }

    @IBSegueAction func initializeProjects(_ coder: NSCoder) -> ProjectCollectionViewController? {
        LogNotify.log("setting project collection view controller")
        projectCollectionViewController = ProjectCollectionViewController(coder: coder)
        self.reloadInputViews()
        return projectCollectionViewController
    }

    @IBAction func createNewProject(_ coder: NSCoder) {
        LogNotify.log("Starting to create a new Project")
        let alertController = UIAlertController(title: NSLocalizedString("Enter an Projectname for the new Project", comment: ""), message: nil, preferredStyle: .alert)
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showNewlyCreatedProject" {
            LogNotify.log("Preparing for segue showNewlyCreatedProject")
            guard let destinationVC = segue.destination as? ProjectViewController else {
                return
            }
            destinationVC.project = Project.fetchProject(id: sender as! Int)!
        }
    }

    @IBAction func openLinkToCalliopeInformation() {
        if let url = URL(string: NSLocalizedString("https://calliope.cc/programmieren/mobil/ipad#sensordaten", comment: "")) {
            UIApplication.shared.open(url)
        }
    }

    @IBAction func getDataloggerHtml() {
        guard let connectedCalliope = self.connectedCalliope else {
            LogNotify.log("Datalogger Data button pressed, while no connected Calliope. This should not happen.")
            return
        }

        self.present(alertView, animated: true)
        connectedCalliope.startUtilityJob(
            for: .LOG_HTML,
            onProgress: { [self] (a) in progressRing.startProgress(to: CGFloat(a), duration: 0.2) },
            onCompletion: {
                self.dismiss(animated: true)
                self.performSegue(withIdentifier: "showDataLoggerHTML", sender: self)
            },
            onFailure: {
                self.dismiss(animated: true)

                let failureReason = connectedCalliope.currentJob?.jobState
                if failureReason == .Canceled {
                    return
                }

                let alert = UIAlertController(
                    title: NSLocalizedString("Datalogger Download Failed!", comment: ""),
                    message: String(format: NSLocalizedString("There was an issue downloading the datalogger data from your Calliope mini. Please ensure you are connected to the Calliope and try again.", comment: "")),
                    preferredStyle: .alert
                )
                alert.addAction(
                    UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                        self.dismiss(animated: true)
                    })
                self.present(alert, animated: true)
            }
        )
    }

    fileprivate func addNotificationSubscriptions() {
        calliopeConnectedSubcription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDDevice.usageReadyNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    LogNotify.log("Received usage ready Notification")
                    self?.connectedCalliope = MatrixConnectionViewController.instance.usageReadyCalliope as? CalliopeAPI
                    self?.dataloggerInformationButton.isEnabled = self?.connectedCalliope?.discoveredOptionalServices.contains(.microbitUtilityService) ?? false
                }
            })

        calliopeDisconnectedSubscription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDDevice.disconnectedNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.dataloggerInformationButton.isEnabled = false
                }
            })
    }

    // UI Components for displaying Datalogger Loading
    private lazy var alertView: UIAlertController = {
        let uploadController = UIAlertController(title: NSLocalizedString("Transfering Datalogger Data", comment: ""), message: "", preferredStyle: .alert)

        let progressView: UIView
        let logHeight = 0


        progressView = progressRing
        progressView.translatesAutoresizingMaskIntoConstraints = false

        uploadController.view.addSubview(progressView)
        uploadController.view.addSubview(logTextView)
        uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(withVisualFormat: "V:|-(80)-[progressView(120)]-(8)-[logTextView(logHeight)]-(50)-|", options: [], metrics: ["logHeight": logHeight], views: ["progressView": progressView, "logTextView": logTextView]))
        uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(80@900)-[progressView(120)]-(80@900)-|",
                options: [], metrics: nil, views: ["progressView": progressView]))

        uploadController.view.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(8@900)-[logTextView(264)]-(8@900)-|",
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
        ring.valueFormatter = UICircularProgressRingFormatter(valueIndicator: "%", rightToLeft: false, showFloatingPoint: false, decimalPlaces: 0)
        return ring
    }()

    private lazy var cancelUploadAction: UIAlertAction = {
        UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive) { [weak self] _ in
            guard let connectedCalliope = self?.connectedCalliope else {
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
}
