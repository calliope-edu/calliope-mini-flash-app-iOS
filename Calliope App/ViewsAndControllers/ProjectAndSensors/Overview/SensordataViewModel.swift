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
    var isUsbMode: Bool { get }
    var alert: (any AppAlert)? { get set }
    var alertBinding: Binding<(any AppAlert)?> { get }
    
    func deleteProject(id: Int64)
    func openBluetoothExtensionPage(openURL: OpenURLAction)
}

class SensordataViewModel: ObservableObject, SensorDataViewModelProtocol, Alertable {
    @Published var projects: [Project] = []
    @Published var dataLoggerButtonEnabled: Bool
    @Published var isUsbMode: Bool
    @Published var alert: (any AppAlert)? = nil
    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }
    
    private var connectedCalliope: Calliope?
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    private var programSubscription: NSObjectProtocol!
    
    init() {
        projects = Project.fetchProjects()

        MatrixConnectionViewModel.instance.calliopeClass = DiscoveredBLEDevice.self

        self.connectedCalliope = MatrixConnectionViewModel.instance.usageReadyCalliope
        let usbMode = MatrixConnectionViewModel.instance.isInUsbMode
        self.isUsbMode = usbMode
        self.dataLoggerButtonEnabled =
            (self.connectedCalliope as? BLECalliope)?.discoveredOptionalServices.contains(.microbitUtilityService) ?? false || usbMode

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

class PreviewSensordataViewModel: SensorDataViewModelProtocol, ObservableObject, Alertable {
    @Published var projects: [Project]
    @Published var dataLoggerButtonEnabled: Bool
    @Published var isUsbMode: Bool
    @Published var alert: (any AppAlert)? = nil
    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }
    
    init(projects: [Project], dataLoggerButtonEnabled: Bool, isUsbMode: Bool = false) {
        self.projects = projects
        self.dataLoggerButtonEnabled = dataLoggerButtonEnabled
        self.isUsbMode = isUsbMode
    }
    
    func deleteProject(id: Int64) {
        
    }
    func openBluetoothExtensionPage(openURL: OpenURLAction) {
        
    }
}
