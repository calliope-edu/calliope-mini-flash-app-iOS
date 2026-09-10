//
//  ProjectController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import SwiftUI

class ProjectViewModel: ObservableObject, Alertable {

    @Published var project: Project?
    @Published var addGroupButtonEnabled = false
    @Published var groupViewModels: [GroupViewModel] = []
    @Published var alert: AppAlert? = nil
    var alertBinding: Binding<AppAlert?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }

    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    private let onDelete: () -> Void

    /// The Bluetooth-connected Calliope mini, if it can deliver sensor values.
    ///
    /// Recording reads `CalliopeAPI` characteristics, so it needs a Bluetooth
    /// connection — a USB-connected Calliope has none. `usageReadyCalliope`
    /// cannot be used for this check: it follows the USB/Bluetooth switch, so
    /// while the switch sits on USB it reports the USB device (or nil) even
    /// though a Bluetooth Calliope is connected and perfectly usable here.
    private var sensorCapableCalliope: CalliopeAPI? {
        MatrixConnectionViewModel.instance.connector
            .connectedCalliope?.usageReadyCalliope as? CalliopeAPI
    }

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

    init(project: Project, onDelete: @escaping () -> Void = {}) {
        self.project = project
        self.onDelete = onDelete

        loadGroups()

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

        guard sensorCapableCalliope != nil else {
            addGroupButtonEnabled = false
            showConnectCalliopeAlert()
            return
        }

        addGroupButtonEnabled = true
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
            self.addGroupButtonEnabled = value
        }
    }

    private func showConnectCalliopeAlert() {
        alert = .connectCalliopeRequired()
    }

    func renameProject() {
        alert = .renameProject(defaultName: project?.name ?? "") { [weak self] newName in
            self?.project?.name = newName
            if let project = self?.project {
                Project.updateProject(project: project)
                NotificationCenter.default.post(
                    name: NotificationConstants.projectsChanged,
                    object: self
                )
            }
        }
    }

    func deleteProject() {
        Project.deleteProject(id: project?.id)
        NotificationCenter.default.post(
            name: NotificationConstants.projectsChanged,
            object: self
        )
        onDelete()
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
        alert = .exportCSVName(onOk: onOk)
    }

    func stopRecording() {
        groupViewModels.forEach { $0.chartViewModels.forEach { $0.stopRecording() } }
    }

    deinit {
        NotificationCenter.default.removeObserver(calliopeConnectedSubcription!)
        NotificationCenter.default.removeObserver(calliopeDisconnectedSubscription!)
    }

}
