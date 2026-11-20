//
//  DeviceDiagnostics.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import UIKit
import Foundation
import CoreBluetooth

struct DeviceDiagnostics {

    let usbPolicy: USBTransferPolicy
    var defaults: UserDefaults = .standard
    var iCloudContainerIdentifier = StorageDirectory.containerIdentifier

    // MARK: - Public API

    @MainActor
    func collect() async -> DiagnosticsReport {
        let containerIdentifier = iCloudContainerIdentifier
        // Looking up the container can block while iCloud sets it up.
        let hasICloudContainer = await Task.detached {
            FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) != nil
        }.value

        return DiagnosticsReport(sections: [
            appSection(),
            deviceSection(),
            sharedIPadSection(),
            iCloudSection(hasContainer: hasICloudContainer),
            bluetoothSection(),
        ])
    }

    static func sharedIPadSource(defaults: UserDefaults) -> String {
        if defaults.object(forKey: Keys.sharedIPadOverride) != nil {
            return "Override (\(defaults.bool(forKey: Keys.sharedIPadOverride)))"
        }
        if let flag = defaults.dictionary(forKey: Keys.managedConfiguration)?[Keys.managedSharedIPad] as? Bool {
            return "Managed App Config (\(flag))"
        }
        return "Not configured"
    }

    // MARK: - Sections

    private func appSection() -> DiagnosticsReport.Section {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return DiagnosticsReport.Section(title: "App", entries: [
            .init(label: "Version", value: "\(version) (\(build))"),
            .init(label: "Report created", value: ISO8601DateFormatter().string(from: Date())),
        ])
    }

    @MainActor
    private func deviceSection() -> DiagnosticsReport.Section {
        let device = UIDevice.current
        let process = ProcessInfo.processInfo
        return DiagnosticsReport.Section(title: "Device", entries: [
            .init(label: "Model identifier", value: device.model),
            .init(label: "Connector", value: device.hasUSBC ? "USB-C" : "Lightning"),
            .init(label: "System", value: "\(device.systemName) \(device.systemVersion)"),
            .init(label: "OS build", value: process.operatingSystemVersionString),
            .init(label: "Region", value: Locale.current.identifier),
        ])
    }

    private func sharedIPadSection() -> DiagnosticsReport.Section {
        let managedKeys = defaults.dictionary(forKey: Keys.managedConfiguration)?.keys.sorted() ?? []
        return DiagnosticsReport.Section(title: "Shared iPad", entries: [
            .init(label: "Treated as Shared iPad", value: Self.yesNo(usbPolicy.isSharedIPad)),
            .init(label: "Detected via", value: Self.sharedIPadSource(defaults: defaults)),
            .init(label: "Managed App Config keys", value: managedKeys.isEmpty ? "None" : managedKeys.joined(separator: ", ")),
            .init(label: "USB destination picked per flash", value: Self.yesNo(usbPolicy.picksDestinationPerFlash)),
        ])
    }

    private func iCloudSection(hasContainer: Bool) -> DiagnosticsReport.Section {
        DiagnosticsReport.Section(title: "iCloud", entries: [
            .init(label: "Signed in", value: Self.yesNo(FileManager.default.ubiquityIdentityToken != nil)),
            .init(label: "App container available", value: Self.yesNo(hasContainer)),
        ])
    }

    private func bluetoothSection() -> DiagnosticsReport.Section {
        DiagnosticsReport.Section(title: "Bluetooth", entries: [
            .init(label: "Permission", value: Self.bluetoothAuthorization(CBManager.authorization)),
        ])
    }

    // MARK: - Private Helpers

    private enum Keys {
        static let sharedIPadOverride = "sharedIPadOverride"
        static let managedConfiguration = "com.apple.configuration.managed"
        static let managedSharedIPad = "sharedIPad"
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private static func bluetoothAuthorization(_ authorization: CBManagerAuthorization) -> String {
        switch authorization {
        case .allowedAlways: return "Allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }
}
