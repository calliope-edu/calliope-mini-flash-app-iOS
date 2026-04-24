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
import SwiftUI

class ProjectViewController: UIViewController, ChartViewDelegate, ObservableObject {

    @Published var project: Project?
    @Published var addChartButtonEnabled = false

//    @objc var chartCollectionViewController: ChartCollectionViewController?

    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    
    init?(coder: NSCoder, project: Project) {
        self.project = project
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        guard project != nil else {
            LogNotify.log("Project was not set. This is not supposed to happen.", level: LogNotify.LEVEL.ERROR)
            return nil
        }
        return UIHostingController(coder: coder, rootView: ProjectView(projectViewController: self))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        calliopeConnectedSubcription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDevice.usageReadyNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.5) {
                        self?.addChartButtonEnabled = true
                    }
                }
            })

        calliopeDisconnectedSubscription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDevice.disconnectedNotificationName, object: nil, queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.5) {
                        self?.addChartButtonEnabled = false
                    }
                }
            })

        guard let _ = MatrixConnectionViewController.instance.usageReadyCalliope else {
            addChartButtonEnabled = false
            DispatchQueue.main.async {
                let alert = UIAlertController(title: NSLocalizedString("Calliope mini verbinden!", comment: ""), message: NSLocalizedString("Verbindung notwendig, um Daten anzeigen zu lassen.", comment: ""), preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                self.present(alert, animated: true, completion: nil)
            }
            return
        }
        
        addChartButtonEnabled = true
    }
    
//    @IBSegueAction func initializeCharts(_ coder: NSCoder) -> ChartCollectionViewController? {
//        chartCollectionViewController = ChartCollectionViewController(coder: coder)
//        self.reloadInputViews()
//        return chartCollectionViewController
//    }
//
    func addNewSensor() {
        // TODO: imlement
    }

    func renameProject() {
        let alertController = UIAlertController(title: NSLocalizedString("Change project name", comment: ""), message: NSLocalizedString("Enter the new project name", comment: ""), preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = NSLocalizedString("New project", comment: "")
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let inputText = textField.text {
                self.project?.name = inputText
//                self.projectNameLabel.text = inputText
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

    func exportToCSVFile() {
        let alertController = UIAlertController(title: NSLocalizedString("Export Data", comment: ""), message: NSLocalizedString("Enter the CSV file name", comment: ""), preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "CSV_Export"
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
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

//    override func viewDidDisappear(_ animated: Bool) {
//        for cell in chartCollectionViewController!.tableView.visibleCells {
//            let dataCell = cell as! ChartViewCell
//            dataCell.stopDataRecording()
//        }
//    }

}
