//
//  EditorsAndProgramsViewModel.swift
//  Calliope App
//
//  Created by Calliope on 19.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

class EditorsAndProgramsViewModel: ObservableObject {
    @Published var editors: [String] = ["Makecode", "Open Roberta Lab", "Calliope mini Blocks", "MicroPython", "Arcade (USB only)"]
}
