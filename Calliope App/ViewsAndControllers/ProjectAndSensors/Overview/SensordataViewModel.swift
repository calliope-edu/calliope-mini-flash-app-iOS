//
//  SensordataViewModel.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

class SensordataViewModel: ObservableObject {
    @Published var projects: [Project] = []
    
    init() {
        projects = Project.fetchProjects()
    }
}

class PreviewSensordataViewModel: SensordataViewModel {
    override init() {
        super.init()
        projects = [Project(id: 1, name: "Test 1"), Project(id: 2, name: "Test 2"), Project(id: 3, name: "This is a long test name")]
    }
}
