//
//  ArcadeViewModel.swift
//  Calliope App
//
//  Created by Calliope on 01.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

protocol ArcadeViewModelProtocol {
    func openArcadeButtonTapped()
}

class ArcadeViewModel: ArcadeViewModelProtocol, ObservableObject {
    let openArcade: () -> Void
    
    init(openArcade: @escaping () -> Void) {
        self.openArcade = openArcade
    }
    
    func openArcadeButtonTapped() {
        openArcade()
    }
}

class PreviewArcadeViewModel: ArcadeViewModelProtocol, ObservableObject {
   func openArcadeButtonTapped() {
       LogNotify.debug("Trying to open Arcade")
    }
}
