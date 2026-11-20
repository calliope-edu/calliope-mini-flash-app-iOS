//
//  ConnectionPanel.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol ConnectionPanel: AnyObject {
    func animateBounce()
    func setMatrixString(pattern: String)
}

final class PreviewConnectionPanel: ConnectionPanel {
    func animateBounce() {}
    func setMatrixString(pattern: String) {}
}
