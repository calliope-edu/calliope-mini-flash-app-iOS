//
//  ProjectsInfoView.swift
//  Calliope App
//
//  Created by Calliope on 18.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct ProjectsInfoView: View {
    var router: Router<ProjectAndSensorsRoute>

    var body: some View {
        AdaptiveColumnLayout {
            VStack(spacing: 16) {
                Image("calliope_bluetooth_extension 1")
                    .resizable().scaledToFit().frame(maxHeight: 200)
            }
        } right: {

            VStack(alignment: .leading, spacing: 16) {
                Text("Live Bluetooth Sensor Data").fontWeight(.bold)
                Text(
                    "Send sensor data live from your Calliope mini to the app via Bluetooth."
                )

                HStack(alignment: .center) {
                    Image("num_01").resizable().scaledToFit().frame(maxHeight: 35)
                    Text(
                        "Use the example program, or create your own MakeCode project and add the Bluetooth extension."
                    )
                }

                HStack {
                    Spacer()
                    HStack {
                        Text("Open Example Program")
                        Image(systemName: "arrow.up.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.calliopePink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .frame(width: 300)
                    .onTapGesture {
                        router.push(.infoWebView(url: URL(string: "https://makecode.calliope.cc/#pub:_30A13o6dM9L2")!))
                    }
                    Spacer()
                }

                HStack(alignment: .center) {
                    Image("num_02").resizable().scaledToFit().frame(maxHeight: 35)
                    Text("Select the desired services for your program to view or record.")
                }

                HStack(alignment: .center) {
                    Image("num_03").resizable().scaledToFit().frame(maxHeight: 35)
                    Text("Start the program on your Calliope mini.")
                }

                HStack(alignment: .center) {
                    Image("num_04").resizable().scaledToFit().frame(maxHeight: 35)
                    Text("Create new project on the Sensordata page and start recording.")
                }

                Link(
                    "More detailed instructions on calliope.cc",
                    destination: URL(string: "https://calliope.cc/programmieren/mobil/ipad#sensordaten")!
                )
                .font(.subheadline)
            }

        }
    }

}

struct ProjectsInfoView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectsInfoView(router: Router<ProjectAndSensorsRoute>()).previewInterfaceOrientation(.landscapeLeft)
        ProjectsInfoView(router: Router<ProjectAndSensorsRoute>()).previewInterfaceOrientation(.portrait)
    }
}
