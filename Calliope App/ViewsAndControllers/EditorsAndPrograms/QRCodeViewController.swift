//
//  QRCodeController.swift
//  Calliope App
//
//  Created by itestra on 12.12.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftUI

class QRCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var foundQrCodeString = ""
    
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: QRCodeView(openEditor: openEditor))
    }
    
    func openEditor(_ url: String) {
       foundQrCodeString = url
        performSegue(withIdentifier: "showMakecode", sender: nil)
    }
    
    @IBSegueAction func createMakecodeEditor(_ coder: NSCoder) -> EditorViewController? {
        let editor = MakeCode()
        editor.url = URL.init(string: foundQrCodeString)
        return EditorViewController(coder: coder, editor: editor)
    }
}
