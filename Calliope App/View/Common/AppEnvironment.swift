//
//  AppEnvironment.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

// Inert defaults for previews; the environment setter reads the default, so it must not trap.
private struct DeviceConnectionKey: EnvironmentKey {
    static let defaultValue: DeviceConnectionService = PreviewDeviceConnectionService()
}

private struct ConnectionPanelKey: EnvironmentKey {
    static let defaultValue: ConnectionPanel = PreviewConnectionPanel()
}

// The real storage, so a view that misses the injection still saves to the right folder.
private struct DocumentStorageKey: EnvironmentKey {
    static let defaultValue: DocumentStorage = FileDocumentStorage()
}

extension EnvironmentValues {
    var deviceConnection: DeviceConnectionService {
        get { self[DeviceConnectionKey.self] }
        set { self[DeviceConnectionKey.self] = newValue }
    }

    var connectionPanel: ConnectionPanel {
        get { self[ConnectionPanelKey.self] }
        set { self[ConnectionPanelKey.self] = newValue }
    }

    var documentStorage: DocumentStorage {
        get { self[DocumentStorageKey.self] }
        set { self[DocumentStorageKey.self] = newValue }
    }
}
