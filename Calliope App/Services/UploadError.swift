//
//  UploadError.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

enum UploadError: Error {
    case notConnected
    case incompatibleHex
    case connectionLost
    case dfu(String)
}
