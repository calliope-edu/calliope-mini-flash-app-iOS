//
//  CampusView.swift
//  Calliope App
//
//  Created by Calliope on 11.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

struct CampusView: View {
    @ObservedObject var viewModel: CampusViewModel
    @EnvironmentObject private var uploadViewModel: UploadViewModel
    @Environment(\.deviceConnection) private var connection
    @Environment(\.connectionPanel) private var connectionPanel

    var body: some View {
        EditorWebViewRepresentable(
            editor: viewModel.editor,
            alertPublisher: viewModel,
            connection: connection,
            connectionPanel: connectionPanel,
            uploadFirmware: uploadViewModel.uploadWithoutConfirmation
        )
            .modifier(AlertModifier(alert: viewModel.alertBinding))
    }
}
