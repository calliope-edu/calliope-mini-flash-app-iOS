//
//  ProjectView.swift
//  Calliope App
//
//  Created by Calliope on 17.04.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Charts
import Foundation
import MapKit
import SwiftUI

struct ProjectDetailView: View {
    let projectID: Int64
    var onDelete: () -> Void
    @StateObject var viewModel: ProjectViewModel

    init(projectID: Int64, connection: DeviceConnectionService, documentStorage: DocumentStorage, onDelete: @escaping () -> Void) {
        self.projectID = projectID
        self.onDelete = onDelete
        _viewModel = StateObject(
            wrappedValue: ProjectViewModel(
                project: Project.fetchProject(id: Int(projectID)) ?? Project(id: projectID, name: ""),
                connection: connection,
                documentStorage: documentStorage,
                onDelete: onDelete
            )
        )
    }

    var body: some View {
        ProjectView(viewModel: viewModel)
    }
}

struct ProjectView: View {
    @ObservedObject var viewModel: ProjectViewModel
    var body: some View {
        ScrollView {
            VStack {
                SizedBox(height:2)
                ForEach(viewModel.groupViewModels) { groupViewModel in
                    GroupView(viewModel: groupViewModel)
                }
                addGroupButton
            }
        }
        .onDisappear {
            viewModel.stopRecording()
        }
        .modifier(AlertModifier(alert: viewModel.alertBinding))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    Button("Rename") { viewModel.renameProject() }
                    Button("Export (CSV)") { viewModel.exportToCSVFile() }
                    Button("Delete", role: .destructive) { viewModel.deleteProject() }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.project!.name)
                            .font(.headline)
                            .textCase(.uppercase)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    var addGroupButton: some View {
        Button(action: viewModel.addGroup) {
            Label("Record sensor data", systemImage: "plus")
        }
        .buttonStyle(.pill)
    }

}

struct IconButton: View {
    var imageSystemName: String
    var action: () -> Void
    var rotation: Double
    var iconColor: Color
    var backgroundColor: Color

    var body: some View {
        Button(action: action) {
            Image(systemName: imageSystemName)
                .font(.system(size: 32))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(rotation))
                .background(Circle().fill(backgroundColor).frame(width: 44, height: 44))
        }
    }
}

struct ProjectView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectView(viewModel: ProjectViewModel(project: Project(id: 1, name: "Test"), connection: PreviewDeviceConnectionService(), documentStorage: FileDocumentStorage()))
    }
}
