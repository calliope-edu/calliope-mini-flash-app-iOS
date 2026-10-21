//
//  OfflineOnboardingView.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct OfflineOnboardingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("You are offline. However, we have some information for you!").font(.largeTitle)
                Text("Start Bluetooth Mode").font(.title)
                centerImage(Image("CalliopeApp_Verbinden_Bluetooth"))

                Text("Calliope mini V3").font(.headline)
                Text("- Press the Reset button 3 times")
                Text("- An ID pattern appears on the Calliope mini")

                Text("Calliope mini V2/V1").font(.headline)
                Text("- Hold down buttons A+B")
                Text("- Additionally press the Reset button for 1 second")
                Text("- Keep holding buttons A+B until the Bluetooth animation ends")
                Text("- An ID pattern appears on the Calliope mini")
                Text("")

                Text("Connect").font(.title)
                centerImage(Image("CalliopeApp_Verbinden_ID-Muster"))
                Text("- The connection window opens via the red Calliope mini icon in the Editors and Programs section")
                Text("- Transfer the Calliope mini's unique ID pattern to the matrix")
                Text("- If the Calliope mini is found, a green button appears")
                Text("- Confirm the connection by pressing the green button")
                Text("")

                Text("Transfer Program").font(.title)
                centerImage(Image("CalliopeApp_Verbinden_Uebertragung_DE"))
                Text("- Use an editor to create and transfer a program")
                Text("- From now on, you can transfer programs from the app via Bluetooth")
                Text(
                    "- To transfer a program to the Calliope mini: Download, save, and transfer the program. This may take a few seconds. Progress will be displayed."
                )
                Text("- The program now appears on the Calliope mini")
            }.padding()
        }
    }
    
    func centerImage(_ image: Image) -> some View {
        HStack {
            Spacer()
            image
            Spacer()
        }
        
    }
}

#Preview {
    OfflineOnboardingView()
}
