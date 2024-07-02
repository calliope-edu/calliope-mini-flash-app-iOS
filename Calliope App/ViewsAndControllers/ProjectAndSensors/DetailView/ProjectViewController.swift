//
//  ProjectController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import DGCharts

class ProjectViewController: UIViewController, ChartViewDelegate {
    
    var project: Project?
    var projectId: Int?
    
    @IBOutlet weak var chartsContainerView: UIView?
    @IBOutlet weak var projectNameLabel: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var addChartButton: UIButton!
    
    @objc var chartCollectionViewController: ChartCollectionViewController?
    var chartHeightConstraint: NSLayoutConstraint?
    var chartsKvo: Any?
    
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    
    init?(coder: NSCoder, project: Project) {
        self.project = project
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        projectNameLabel.text = project?.name
        
        chartsContainerView?.translatesAutoresizingMaskIntoConstraints = false
        chartHeightConstraint = chartsContainerView?.heightAnchor.constraint(equalToConstant: 10)
        chartHeightConstraint?.isActive = true
        
        chartCollectionViewController?.project = project
        setupProjectSettingsMenu()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        chartsKvo = observe(\.chartCollectionViewController?.collectionView.contentSize) { (containerVC, _) in
            UIView.animate(withDuration: 1.0) {
                containerVC.chartHeightConstraint!.constant = containerVC.chartCollectionViewController!.collectionView.contentSize.height
                containerVC.chartCollectionViewController?.collectionView.layoutIfNeeded()
                self.view.layoutIfNeeded()
            }
        }
        
        addChartButton.isEnabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        chartsKvo = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        calliopeConnectedSubcription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDDevice.usageReadyNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.5) {
                        self?.addChartButton.isEnabled = true
                    }
                }
        })
        
        calliopeDisconnectedSubscription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDDevice.disconnectedNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.5) {
                        self?.addChartButton.isEnabled = false
                    }
                }
        })
        
        guard let calliope = MatrixConnectionViewController.instance.usageReadyCalliope else {
            self.addChartButton.isEnabled = false
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Calliope mini verbinden!", message: "Verbindung notwendig, um Daten anzeigen zu lassen.", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                self.present(alert, animated: true, completion: nil)
            }
            return
        }
        self.addChartButton.isEnabled = true
    }
    
    @IBSegueAction func initializeCharts(_ coder: NSCoder) -> ChartCollectionViewController? {
        chartCollectionViewController = ChartCollectionViewController(coder: coder)
        self.reloadInputViews()
        return chartCollectionViewController
    }
    
    @IBAction func recordNewSensor() {
        chartCollectionViewController?.addChart()
    }
    
    func renameProject() {
        let alertController = UIAlertController(title: "Change project name", message: "Enter the new project name", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "New project name"
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let inputText = textField.text {
                self.project?.name = inputText
                self.projectNameLabel.text = inputText
                if let project = self.project {
                    Project.updateProject(project: project)
                    NotificationCenter.default.post(name: NotificationConstants.projectsChanged, object: self)
                }
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func deleteProject() {
        Project.deleteProject(id: project?.id)
        NotificationCenter.default.post(name: NotificationConstants.projectsChanged, object: self)
        dismiss(animated: true, completion: nil)
        navigationController?.popViewController(animated: true)
    }
    
    func setupProjectSettingsMenu() {
        settingsButton.showsMenuAsPrimaryAction = true
            
        let optionClosure = {(action: UIAction) in
            print("Pressed")
        }
        
        settingsButton.menu = UIMenu(children: [
            UIAction(title: "Delete", image: UIImage(systemName: "trash")) {(action: UIAction) in
                self.deleteProject()
            },
            UIAction(title: "Export", image: UIImage(systemName: "square.and.arrow.up")) {(action: UIAction) in
                self.exportToCSVFile()
            },
            UIAction(title: "Rename", image: UIImage(systemName: "pencil")) {(action: UIAction) in
                self.renameProject()
            }
        ])
    }
    
    func exportToCSVFile() {
        let alertController = UIAlertController(title: "Export Data", message: "Enter the CSV File name", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "CSV_Export"
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let inputText = textField.text {
                let string = CSVHandler.convertToCSVString(project: self.project?.id ?? nil)
                CSVHandler.exportToCSVFile(contents: string, fileName: (inputText == "" ? textField.placeholder : inputText) ?? "placeholder")
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(calliopeConnectedSubcription!)
        NotificationCenter.default.removeObserver(calliopeDisconnectedSubscription!)
    }

}
