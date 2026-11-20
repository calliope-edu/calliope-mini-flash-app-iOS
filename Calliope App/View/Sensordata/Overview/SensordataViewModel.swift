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
    var alert: AppAlert? { get set }
    var alertBinding: Binding<AppAlert?> { get }
    
    func deleteProject(id: Int64)
    func openBluetoothExtensionPage(openURL: OpenURLAction)
    func importDataLogger(from result: Result<URL, Error>) -> URL?
}

class SensordataViewModel: ObservableObject, SensorDataViewModelProtocol, Alertable {
    @Published var projects: [Project] = []
    @Published var dataLoggerButtonEnabled: Bool
    @Published var isUsbMode: Bool
    @Published var alert: AppAlert? = nil
    var alertBinding: Binding<AppAlert?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }
    
    let connection: DeviceConnectionService
    private var connectedCalliope: Calliope?
    private var calliopeConnectedSubcription: NSObjectProtocol!
    private var calliopeDisconnectedSubscription: NSObjectProtocol!
    private var programSubscription: NSObjectProtocol!
    
    init(connection: DeviceConnectionService) {
        self.connection = connection
        projects = Project.fetchProjects()

        self.connectedCalliope = connection.currentCalliope
        let usbMode = connection.isUsbMode
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
    
    func importDataLogger(from result: Result<URL, Error>) -> URL? {
        do {
            let data = try result.get().asData()
            // Every datalogger page loads the log viewer script (dl.js); other HTML files would show an empty page.
            guard String(decoding: data, as: UTF8.self).contains("/dl.js") else {
                alert = .ok(
                    title: NSLocalizedString("Not a Datalogger File", comment: ""),
                    message: NSLocalizedString("Please choose the MY_DATA.HTM file recorded by the datalogger on your Calliope mini.", comment: ""),
                    completion: {}
                )
                return nil
            }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("datalogger_\(Int(Date().timeIntervalSince1970)).htm")
            try data.write(to: tempURL)
            return tempURL
        } catch {
            LogNotify.log("Failed to import datalogger file: \(error)")
            alert = .ok(
                title: NSLocalizedString("Datalogger Import Failed!", comment: ""),
                message: NSLocalizedString("The selected file could not be read. Please try again.", comment: ""),
                completion: {}
            )
            return nil
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
                    self?.connectedCalliope = self?.connection.currentCalliope
                    self?.isUsbMode = self?.connection.isUsbMode ?? false
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
    @Published var alert: AppAlert? = nil
    var alertBinding: Binding<AppAlert?> {
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
    func importDataLogger(from result: Result<URL, Error>) -> URL? {
        nil
    }
}
