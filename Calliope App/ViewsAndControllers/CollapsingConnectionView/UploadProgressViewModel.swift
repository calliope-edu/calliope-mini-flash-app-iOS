//
//  UploadProgressModel.swift
//  Calliope App
//
//  Created by Calliope on 07.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

class UploadProgressViewModel: ObservableObject {
    static let instance = UploadProgressViewModel()

    @Published var isUploading: Bool = false
    @Published var progress: Double = 0.0       // 0.0 ... 1.0
    @Published var isExpanded: Bool = false
    @Published var isIndeterminate: Bool = false
    @Published var statusText: String = ""

    var cancelAction: (() -> Void)?

    func startUpload(isIndeterminate: Bool = false, statusText: String = "") {
        if isUploading {
            LogNotify.debug("Started upload while another one is running. Canceling the current upload in favor or the new one.")
            cancel()
        }
        isUploading = true
        progress = 0.0
        isExpanded = false
        self.isIndeterminate = isIndeterminate
        self.statusText = statusText
    }

    func updateProgress(_ value: Double) {
        if isUploading {
            progress = min(max(value, 0.0), 1.0)
        }
    }

    func finishUpload() {
        isUploading = false
        progress = 0.0
        isExpanded = false
        isIndeterminate = false
        statusText = ""
        cancelAction = nil
    }

    func cancel() {
        cancelAction?()
        finishUpload()
    }
}
