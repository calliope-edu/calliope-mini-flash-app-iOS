//
//  LofiAppsViewController.swift
//  Calliope App
//
//  Created by OpenAI Assistant on 2026-02-20.
//

import UIKit

/// A blank view controller displayed under the new "LofiApps" tab.
final class LofiAppsViewController: UIViewController {
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLabel()
    }
    
    // MARK: - Private UI
    private func setupLabel() {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Lofi Apps"
        label.textColor = .label
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
