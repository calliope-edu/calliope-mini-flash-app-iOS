//
//  PlaygroundSnippetTableViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 31.12.20.
//  Copyright © 2020 calliope. All rights reserved.
//

import UIKit
import MobileCoreServices

class PlaygroundSnippetTableViewController: UITableViewController, UITableViewDragDelegate {

    var secondary: CodeSnippetController? {

        if #available(iOS 14.0, *) {
            let secondary = splitViewController?.viewController(for: .secondary) as? CodeSnippetController
            if secondary != nil {
                return secondary
            }
        }

        let secondary = (splitViewController?.viewControllers.last as? UINavigationController)?.viewControllers.first as? CodeSnippetController
        if secondary != nil {
            return secondary
        }

        return storyboard?.instantiateViewController(withIdentifier: "playgroundCodeSnippetViewController") as? CodeSnippetController
    }

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()

        tableView.dragInteractionEnabled = true
        tableView.dragDelegate = self

        CodeSnippets.reload(failure: { error in
            let errorDescription = error?.localizedDescription ?? NSLocalizedString("No description available", comment: "")
            let alert = UIAlertController(title: NSLocalizedString("Failed to load snippets", comment: ""), message: String(format:NSLocalizedString("Check your internet connection or the snippets url in settings.\n\nThe error description is:\n%@", comment: ""), errorDescription), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))
            DispatchQueue.main.async {
                self.parent?.dismiss(animated: true) {
                    UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true)
                }
            }
        }) { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(copyCode(_:)))
            self.view.addGestureRecognizer(longPressRecognizer)
    }

    @objc
    func copyCode(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        guard longPressGestureRecognizer.state == .began else {
            return
        }
        let touchPoint = longPressGestureRecognizer.location(in: self.tableView)
        guard let indexPath = tableView.indexPathForRow(at: touchPoint),
           let cell = tableView.cellForRow(at: indexPath) as? PlaygroundSnippetTableViewCell
        else {
            return
        }
        cell.copyCode()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MatrixConnectionViewController.instance?.calliopeClass = nil
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CodeSnippets.cached.snippets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "snippetOverviewCell", for: indexPath) as! PlaygroundSnippetTableViewCell

        cell.snippet = CodeSnippets.cached.snippets[indexPath.row]

        cell.copySuccessOverlay?.effect = nil

        return cell
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let secondary = secondary else {
            return
        }

        secondary.codeSnippet = CodeSnippets.cached.snippets[indexPath.row]
        splitViewController?.showDetailViewController(secondary, sender: self)
    }

    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let codeSnippet = (tableView.cellForRow(at: indexPath) as? PlaygroundSnippetTableViewCell)?.snippet, let data = codeSnippet.content.data(using: .utf8) else {
            return []
        }
        let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: kUTTypeUTF8PlainText as String)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }
}
