//
//  ProjectController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Charts
import DGCharts
import Foundation
import SwiftUI
import UIKit

class ProjectViewModel: UIViewController, ChartViewDelegate, ObservableObject {

    @Published var project: Project?
    @Published var addGroupButtonEnabled = false
    @Published var groupViewModels: [GroupViewModel] = []

    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!

    func loadGroups() {
        guard project != nil else {
            LogNotify.error("Project was not set. This is not supposed to happen.")
            return
        }
        let groups = Group.fetchGroupsBy(projectId: project!.id!)
        groupViewModels = groups.map {
            GroupViewModel(
                group: $0,
                openFileNameDialog: openFileNameDialog,
                deleteGroup: deleteGroup
            )
        }
    }

    init?(coder: NSCoder, project: Project) {
        self.project = project
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        loadGroups()
        return UIHostingController(
            coder: coder,
            rootView: ProjectView(viewModel: self)
        )
    }

    fileprivate func addSubscription(name: NSNotification.Name, onActivated: @escaping @Sendable (Notification) -> Void) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: nil,
            using: onActivated
        )
    }

    fileprivate func setAddGroupButton(value: Bool) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5) {
                self.addGroupButtonEnabled = value
            }
        }
    }

    fileprivate func showConnectCalliopeAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: NSLocalizedString("Calliope mini verbinden!", comment: ""),
                message: NSLocalizedString("Verbindung notwendig, um Daten anzeigen zu lassen.", comment: ""),
                preferredStyle: .alert
            )
            let okAction = UIAlertAction(
                title: "OK",
                style: .default,
                handler: nil
            )
            alert.addAction(okAction)
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        // On the new IOS version the gestureRecognizer creates unwanted behaviour, because swipes are not always for navigating back.
        if #available(iOS 26.0, *), let gestureRecognizer = self.navigationController?.interactiveContentPopGestureRecognizer {
            gestureRecognizer.isEnabled = false
        }
>
        calliopeConnectedSubcription = addSubscription(
            name: DiscoveredBLEDevice.usageReadyNotificationName,
            onActivated: { [weak self] (_) in
                self?.setAddGroupButton(value: true)
            }
        )

        calliopeDisconnectedSubscription = addSubscription(
            name: DiscoveredBLEDevice.disconnectedNotificationName,
            onActivated: { [weak self] (_) in
                self?.setAddGroupButton(value: false)
            }
        )

        guard MatrixConnectionViewController.instance.usageReadyCalliope != nil
        else {
            addGroupButtonEnabled = false
            showConnectCalliopeAlert()
            return
        }

        addGroupButtonEnabled = true
    }

    func renameProject() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Change project name", comment: ""),
            message: NSLocalizedString(
                "Enter the new project name",
                comment: ""
            ),
            preferredStyle: .alert
        )
        alertController.addTextField { textField in
            textField.placeholder = NSLocalizedString(
                "New project",
                comment: ""
            )
        }

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .cancel,
            handler: nil
        )
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first,
                let inputText = textField.text
            {
                self.project?.name = inputText
                if let project = self.project {
                    Project.updateProject(project: project)
                    NotificationCenter.default.post(
                        name: NotificationConstants.projectsChanged,
                        object: self
                    )
                }
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }

    func deleteProject() {
        Project.deleteProject(id: project?.id)
        NotificationCenter.default.post(
            name: NotificationConstants.projectsChanged,
            object: self
        )
        dismiss(animated: true, completion: nil)
        navigationController?.popViewController(animated: true)
    }

    func addGroup() {
        guard let project = project else {
            LogNotify.error("Project is nil. This should not happen.")
            return
        }
        guard let group = Group.insertGroup(projectsId: project.id!) else {
            return
        }
        Chart.insertChart(sensorType: nil, groupsId: group.id)
        groupViewModels.append(
            GroupViewModel(
                group: group,
                openFileNameDialog: openFileNameDialog,
                deleteGroup: deleteGroup
            )
        )
    }

    func deleteGroup(groupId: Int64) {
        Group.deleteGroup(groupId: groupId)
        loadGroups()
    }

    func exportToCSVFile() {
        openFileNameDialog(onOk: { filename in
            let string = CSVHandler.convertToCSVString(
                project: self.project?.id ?? nil
            )
            CSVHandler.exportToCSVFile(contents: string, fileName: filename)
        })
    }

    func openFileNameDialog(onOk: @escaping (_ filename: String) -> Void) {
        let alertController = UIAlertController(
            title: NSLocalizedString("Export Data", comment: ""),
            message: NSLocalizedString("Enter the CSV file name", comment: ""),
            preferredStyle: .alert
        )
        alertController.addTextField { textField in
            textField.placeholder = "CSV_Export"
        }

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .cancel,
            handler: nil
        )
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let inputText = textField.text {
                onOk((inputText == "" ? textField.placeholder : inputText) ?? "placeholder")
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

    override func viewDidDisappear(_ animated: Bool) {
        groupViewModels.forEach { $0.chartViewModels.forEach { $0.stopRecording() } }
    }

}
