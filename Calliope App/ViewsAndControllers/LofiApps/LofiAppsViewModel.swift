//
//  LofiAppsViewModel.swift
//  Calliope App
//
//  Created by Calliope on 14.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

class LofiAppsViewModel: ObservableObject, Alertable {
    let infoItem = AppItem(tileItem: TileItem(title: "INFO", imageSource: ImageSource.local("info"), color: Color("calliope-pink"), textColor: .white), url: "https://calliope.cc/programmieren/mobil/ble-anwendungen")
    @Published var tileData = TileData<AppItem>(rightItems: [
        AppItem(tileItem: TileItem(title: "ROBOTER MIT GESICHTSERKENNUNG STEUERN", imageSource: ImageSource.local("facerobot"), color: Color("calliope-lilablau"), textColor: .white), url: "https://go.calliope.cc/facerobot?mobile=true"),
        AppItem(tileItem: TileItem(title: "SPRACHROBOTER", imageSource: ImageSource.local("speak"), color: Color("calliope-orange"), textColor: .white), url: "https://cardboard.lofirobot.com/apps/talking-robots"),
        AppItem(tileItem: TileItem(title: "STEUERUNG PER COMPUTER", imageSource: ImageSource.local("control"), color: Color("calliope-turqoise"), textColor: .white), url: "https://go.calliope.cc/apps/control/index.html?mobile=true"),
        AppItem(tileItem: TileItem(title: "OBJEKTERKENNUNG MIT KÜNSTLICHER INTELLIGENZ", imageSource: ImageSource.local("teachablemachine"), color: Color("calliope-darkgreen"), textColor: .white), url: "https://go.calliope.cc/teachablemachine/index.html?mobile=true"),
    ])

    @Published var alert: (any AppAlert)? = nil
    var alertBinding: Binding<(any AppAlert)?> {
        Binding(
            get: { self.alert },
            set: { self.alert = $0 }
        )
    }
}
