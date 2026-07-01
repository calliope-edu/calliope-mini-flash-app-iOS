//
//  ArcadeViewController.swift
//  Calliope App
//
//  Created by Calliope on 01.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class ArcadeViewController: UIViewController {

    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: ArcadeView(viewModel: ArcadeViewModel(openArcade: openArcade)))
    }
    
    
    func openArcade() {
        let storyboard = UIStoryboard(name: "EditorAndPrograms", bundle: nil)
        if let editorVC = storyboard.instantiateViewController(withIdentifier: "EditorViewController") as? EditorViewController {
            editorVC.editor = ArcadeEditor()
            navigationController?.pushViewController(editorVC, animated: true)
        }
    }
}
