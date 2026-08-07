//
//  EditorAndProgramsContainerViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 07.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import CoreServices
import SwiftUI
import UIKit
import UniformTypeIdentifiers

class EditorAndProgramsContainerViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {

    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(
            coder: coder,
            rootView: EditorsAndProgramsView(
                viewModel: EditorsAndProgramsViewModel()
            )
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        MatrixConnectionViewModel.instance.calliopeClass = DiscoveredBLEDevice.self
    }

}
