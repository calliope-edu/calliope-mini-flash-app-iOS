//
//  CampusViewModel.swift
//  Calliope App
//
//  Created by Calliope on 11.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

final class CampusViewModel: ObservableObject, Alertable {
    let editor: CampusEditor

    @Published var alert: AppAlert? = nil
    var alertBinding: Binding<AppAlert?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }

    init(settings: SettingsStore) {
        editor = CampusEditor(campusUrl: settings.campusUrl)
    }
}
