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

struct ProjectView: View {
    @ObservedObject var viewModel: ProjectViewModel
    @State var showMenu = false

    var body: some View {
        VStack {
            HStack {
                Text(viewModel.project!.name)
                    .foregroundColor(.white)
                    .font(.title)
                Spacer()
                projectSettingsButton
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("calliope-turqoise"))
            )
            .padding(.horizontal)

            ScrollView {
                VStack {
                    ForEach(viewModel.groupViewModels) { groupViewModel in
                        GroupView(viewModel: groupViewModel)
                    }
                    addGroupButton
                }
            }
        }.frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
    }

    var addGroupButton: some View {
        IconButton(
            imageSystemName: "plus.circle",
            action: viewModel.addGroup,
            rotation: 0,
            iconColor: Color(.white),
            backgroundColor: viewModel.addGroupButton
                ? Color("calliope-turqoise") : Color(.gray)
        ).disabled(!viewModel.addGroupButton)

    }

    var projectSettingsButton: some View {
        IconButton(
            imageSystemName: "ellipsis.circle",
            action: { showMenu = true },
            rotation: 90,
            iconColor: Color(.white),
            backgroundColor: Color(.white).opacity(0)
        )
        .confirmationDialog(
            "",
            isPresented: $showMenu,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deleteProject()
            }
            Button("Export (CSV)") { viewModel.exportToCSVFile() }
            Button("Rename") { viewModel.renameProject() }
        }
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
                .background(
                    Circle().fill(backgroundColor).frame(width: 44, height: 44)
                )
        }
    }
}

struct ProjectView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectView(viewModel: ProjectViewModel(coder: NSCoder())!)
    }
}
