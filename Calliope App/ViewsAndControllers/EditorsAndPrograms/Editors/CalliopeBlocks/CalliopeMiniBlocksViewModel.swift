//
//  CalliopeMiniBlocksViewModel.swift
//  Calliope App
//
//  Created by Calliope on 01.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

protocol CalliopeMiniBlocksViewModelProtocol {
    var alertBinding: Binding<(any AppAlert)?> { get }
    
    func openLinkToAppStorePage()
    func openLinkToCalliopeBlocksGetStatedPage()
    func uploadBlocksV2Program()
    func uploadBlocksV3Program()
}

class CalliopeMiniBlocksViewModel: CalliopeMiniBlocksViewModelProtocol, ObservableObject, Alertable {
    @Published var alert: (any AppAlert)? = nil
    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }

    func openLinkToAppStorePage() {
        if let url = URL(string: "https://apps.apple.com/de/app/calliope-mini-blocks/id6480199471") {
            UIApplication.shared.open(url)
        }
    }

    /// URL scheme of the Calliope mini Blocks app used to launch it directly.
    /// Update this value if the app registers a different custom URL scheme.
    private let calliopeBlocksAppURLScheme = "scrub://"

    func openLinkToCalliopeBlocksGetStatedPage() {
        // 1. Reset the saved bluetooth pattern so the connection button starts blank
        let blankMatrix = String(repeating: "0", count: 25)
        UserDefaults.standard.set("", forKey: SettingsKey.lastMatrix.rawValue)
        MatrixConnectionViewModel.instance.setMatrixString(pattern: blankMatrix)

        // 2. Open the Calliope mini Blocks app; fall back to the App Store if not installed
        if let appURL = URL(string: calliopeBlocksAppURLScheme),
            UIApplication.shared.canOpenURL(appURL)
        {
            UIApplication.shared.open(appURL)
        } else if let storeURL = URL(string: "https://apps.apple.com/app/id6480199471") {
            UIApplication.shared.open(storeURL)
        }
    }

    func uploadBlocksV2Program() {
        let program = DefaultProgram(
            programName: NSLocalizedString("Mini_Blocks_Program", comment: ""),
            url: "https://go.calliope.cc/downloads/BlocksV2.hex"
        )
        FirmwareUploadSwiftUI.showUIForDownloadableProgram(alertPublisher: self, program: program)
    }

    func uploadBlocksV3Program() {
        let program = DefaultProgram(
            programName: NSLocalizedString("Mini_Blocks_Program", comment: ""),
            url: "https://go.calliope.cc/downloads/BlocksV3.hex"
        )
        FirmwareUploadSwiftUI.showUIForDownloadableProgram(alertPublisher: self, program: program)
    }

}

class PreviewCalliopeMiniBlocksViewModel: CalliopeMiniBlocksViewModelProtocol, ObservableObject {
    @Published var alert: (any AppAlert)? = nil
    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }
    
    func openLinkToAppStorePage() {
        LogNotify.debug("Trying to open link to app store page")
    }

    func openLinkToCalliopeBlocksGetStatedPage() {
        LogNotify.debug("Trying to open link to calliope blocks get started page")
    }

    func uploadBlocksV2Program() {
        LogNotify.debug("Trying to upload blocks v2 program")
    }

    func uploadBlocksV3Program() {
        LogNotify.debug("Trying to upload blocks v3 program")
    }
}
