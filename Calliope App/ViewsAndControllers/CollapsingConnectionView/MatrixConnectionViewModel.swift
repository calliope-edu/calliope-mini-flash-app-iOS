//
//  MatrixConnectionViewModel.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

public enum ConnectionState {
    case disconnected
    case connected
}

/* public enum ConnectionState {
    case initialized
    case waitingForBluetooth
    case searching
    case notFoundRetry
    case readyToConnect
    case connecting
    case testingMode
    case readyToPlay
    case wrongProgram
}*/

/*
 public enum ConnectionState {
        case disabled
        case disconnected
        case connecting
        case connected
        case transmitting
    }
 */

protocol MatrixConnectionViewModelProtocol: ObservableObject {
    var matrix: [[Bool]] { get set }
    var isInUSBMode: Bool { get set }
    var connectionState: ConnectionState { get }

}

class MatrixConnectionViewModel: MatrixConnectionViewModelProtocol {
    @Published var matrix = Array(repeating: Array(repeating: false, count: 5), count: 5)
    @Published var isInUSBMode = false
    @Published var connectionState = ConnectionState.disconnected
}

class PreviewMatrixConnectionViewModel: MatrixConnectionViewModelProtocol {
    @Published var matrix = Array(repeating: Array(repeating: false, count: 5), count: 5)
    @Published var isInUSBMode = false
    @Published var connectionState = ConnectionState.disconnected
}
