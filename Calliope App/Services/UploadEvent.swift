//
//  UploadEvent.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

enum UploadEvent {
    // nil = indeterminate (USB copies report no real progress)
    case progress(Double?)
    case completed
    case cancelled
    case failed(UploadError)
}
