//
//  Project.swift
//  Calliope App
//
//  Created by Calliope on 01.07.25.
//  Copyright © 2025 calliope. All rights reserved.
//

import Foundation

@Observable
public final class ProjectModelData {
    
    var project: Project;
    var charts: [Chart];
    
    init(projectId: Int64) {
        self.project = Project.fetchProject(id: projectId)!
        self.charts = Chart.fetchChartsBy(projectsId: projectId)
    }
    
    
}
