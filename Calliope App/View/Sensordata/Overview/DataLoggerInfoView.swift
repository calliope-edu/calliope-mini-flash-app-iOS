//
//  DataLoggerInfoView.swift
//  Calliope App
//
//  Created by Calliope on 18.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct DataLoggerInfoView: View {
    var router: Router<ProjectAndSensorsRoute>

    var body: some View {
        AdaptiveColumnLayout {
            VStack(spacing: 8) {
                Image("calliope_datalogger_extension")
                    .resizable().scaledToFit().frame(maxHeight: 200)
            }
        } right: {
            VStack(alignment: .leading, spacing: 16) {
                Text("Data Logger").fontWeight(.bold)
                Text(
                    "With the datalogger extension the Calliope mini 3 can record data. Afterwards you can transfer it to the app and view it in a table."
                )

                HStack(alignment: .center) {
                    Image("num_01").resizable().scaledToFit().frame(maxHeight: 35)
                    Text("Use the example program, or create your own MakeCode project and add the DataLogger Extension.")
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
                    .frame(width: 300)
                    .cornerRadius(12).onTapGesture {
                        router.push(.infoWebView(url: URL(string: "https://makecode.calliope.cc/#pub:_Dv9J1xCp6HRy")!))
                    }
                    Spacer()
                }

                HStack(alignment: .center) {
                    Image("num_02").resizable().scaledToFit().frame(maxHeight: 35)
                    Text(
                        "Create the program with the respective data and define the required columns and set the corresponding sensor data as values."
                    )
                }

                HStack(alignment: .center) {
                    Image("num_03").resizable().scaledToFit().frame(maxHeight: 35)
                    Text("Transfer the program to your Calliope mini.")
                }

                HStack(alignment: .center) {
                    Image("num_04").resizable().scaledToFit().frame(maxHeight: 35)
                    Text("Press \"Load Data From Calliope\" on the Sensordata page to display the recorded data.")
                }
            }
        }
    }

}

struct DataLoggerInfoView_Previews: PreviewProvider {
    static var previews: some View {
        DataLoggerInfoView(router: Router<ProjectAndSensorsRoute>()).previewInterfaceOrientation(.landscapeLeft)
        DataLoggerInfoView(router: Router<ProjectAndSensorsRoute>()).previewInterfaceOrientation(.portrait)
    }
}
