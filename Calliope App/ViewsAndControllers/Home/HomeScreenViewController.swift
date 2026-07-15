//
//  HomeScreenViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 13.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Network
import SwiftUI
import UIKit

class HomeScreenViewController: UIViewController {
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: HomeScreenView(viewModel: HomeScreenViewModel()))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // MatrixConnectionViewController.instance?.calliopeClass = nil // TODO: Removes Connector on HomePage -> Is this desired behaviour?
    }
}
