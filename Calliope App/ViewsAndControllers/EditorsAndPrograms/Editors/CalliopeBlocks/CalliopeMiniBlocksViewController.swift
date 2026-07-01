//
//  CalliopeMiniBlocksViewController.swift
//  Calliope App
//
//  Created by Calliope on 01.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class CalliopeMiniBlocksViewController: UIViewController {
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: CalliopeMiniBlocksView(viewModel: CalliopeMiniBlocksViewModel(uploadDownloadableProgram: uploadDownloadableProgram)))
    }
    
    func uploadDownloadableProgram(_ program: DownloadableHexFile) {
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }
}
