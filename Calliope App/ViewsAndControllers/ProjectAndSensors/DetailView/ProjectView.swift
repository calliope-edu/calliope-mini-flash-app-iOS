//
//  SwiftUIView.swift
//  Calliope App
//
//  Created by Calliope on 20.06.25.
//  Copyright © 2025 calliope. All rights reserved.
//

import SwiftUI

struct ProjectView: View {
    @Bindable var projectModelData: ProjectModelData
    
    
    var body: some View {
        ZStack {
            Color.purple
            VStack {
                Text(projectModelData.project.name)
            }
        }
    }
}

#Preview {
    ProjectView(projectModelData: ProjectModelData(projectId: 1))
}
