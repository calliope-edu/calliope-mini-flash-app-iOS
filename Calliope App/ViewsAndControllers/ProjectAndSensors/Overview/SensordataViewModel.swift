//
//  SensordataViewModel.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

protocol SensorDataViewModelProtocol {
    var projects: [Project] { get }
    var dataLoggerButtonEnabled: Bool { get }
    
    func deleteProject(id: Int64)
    func openBluetoothExtensionPage(openURL: OpenURLAction)
    func openBluetoothSensorInfoWebView()
    func openDataLoggerInfoWebView()
    func createNewProject()
    func openProject(project: Project)
    func openDataLogger()
}

class SensordataViewModel: ObservableObject, SensorDataViewModelProtocol {
    @Published var projects: [Project] = []
    @Published var dataLoggerButtonEnabled: Bool
    
    private var targetUrl: URL?
    private var connectedCalliope: Calliope?
    private var isUsbMode: Bool
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    private var programSubscription: NSObjectProtocol!
    private let viewController: SensordataViewController
    
    init(viewController: SensordataViewController) {
        self.viewController = viewController
        projects = Project.fetchProjects()

        MatrixConnectionViewModel.instance.calliopeClass = DiscoveredBLEDevice.self

        self.connectedCalliope = MatrixConnectionViewModel.instance.usageReadyCalliope
        self.isUsbMode = MatrixConnectionViewModel.instance.isInUsbMode
        self.dataLoggerButtonEnabled =
            (self.connectedCalliope as? BLECalliope)?.discoveredOptionalServices.contains(.microbitUtilityService) ?? false || self.isUsbMode

        addNotificationSubscriptions()

    }
    
    func deleteProject(id: Int64) {
        Project.deleteProject(id: id)
        loadProjects()
    }

    func openBluetoothExtensionPage(openURL: OpenURLAction) {
        if let url = URL(string: "https://calliope.cc/programmieren/mobil/ipad#sensordaten") {
            openURL(url)
        }
    }

    func openBluetoothSensorInfoWebView() {
        viewController.openBluetoothSensorInfoWebView()
    }

    func openDataLoggerInfoWebView() {
        viewController.openDataLoggerInfoWebView()
    }

    func createNewProject() {
        LogNotify.log("Starting to create a new Project")
        viewController.createNewProject()
    }

    func openProject(project: Project) {
        viewController.openProject(project: project)
    }

    func openDataLogger() {
        if connectedCalliope == nil {
            LogNotify.error("connectedCalliope is nil. This should not happen.")
            return
        }
        viewController.getDataloggerHtml(connectedCalliope: connectedCalliope!, isUsbMode: isUsbMode)
    }
    
    private func loadProjects() {
        projects = Project.fetchProjects()
    }

    fileprivate func addNotificationSubscriptions() {
        calliopeConnectedSubcription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDevice.usageReadyNotificationName,
            object: nil,
            queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    LogNotify.log("Received usage ready Notification")
                    self?.connectedCalliope = MatrixConnectionViewModel.instance.usageReadyCalliope
                    self?.isUsbMode = MatrixConnectionViewModel.instance.isInUsbMode
                    self?.dataLoggerButtonEnabled =
                        (self?.connectedCalliope as? BLECalliope)?.discoveredOptionalServices.contains(.microbitUtilityService) ?? false
                        || self?.isUsbMode ?? false
                }
            }
        )

        calliopeDisconnectedSubscription = NotificationCenter.default.addObserver(
            forName: DiscoveredBLEDevice.disconnectedNotificationName,
            object: nil,
            queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.connectedCalliope = nil
                    self?.isUsbMode = false
                    self?.dataLoggerButtonEnabled = false
                }
            }
        )

        programSubscription = NotificationCenter.default.addObserver(
            forName: NotificationConstants.projectsChanged,
            object: nil,
            queue: nil,
            using: { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.loadProjects()
                }
            }
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(calliopeConnectedSubcription!)
        NotificationCenter.default.removeObserver(calliopeDisconnectedSubscription!)
        NotificationCenter.default.removeObserver(programSubscription!)
    }
}

class PreviewSensordataViewModel: SensorDataViewModelProtocol, ObservableObject {
    @Published var projects: [Project]
    @Published var dataLoggerButtonEnabled: Bool
    
    init(projects: [Project], dataLoggerButtonEnabled: Bool) {
        self.projects = projects
        self.dataLoggerButtonEnabled = dataLoggerButtonEnabled
    }
    
    func deleteProject(id: Int64) {
        
    }
    func openBluetoothExtensionPage(openURL: OpenURLAction) {
        
    }
    func openBluetoothSensorInfoWebView() {
        
    }
    func openDataLoggerInfoWebView() {
        
    }
    func createNewProject() {
        
    }
    func openProject(project: Project) {
        
    }
    func openDataLogger() {
        
    }
}
