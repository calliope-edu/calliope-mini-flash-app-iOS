//
//  DisableSwipeBackGestureView.swift
//  Calliope App
//
//  Created by Calliope on 20.11.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI
import UIKit

struct DisableSwipeBackGestureView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DisableSwipeBackViewController {
        DisableSwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: DisableSwipeBackViewController, context: Context) {}
}

final class DisableSwipeBackViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        if #available(iOS 26.0, *) {
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = false
        }
    }
}
