//
//  PlaygroundSnippetTableViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 31.12.20.
//  Copyright © 2020 calliope. All rights reserved.
//

import UIKit

class PlaygroundSnippetTableViewController: UITableViewController {

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
        super.viewDidLoad()

        CodeSnippets.reload { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
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

        return cell
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let secondary = secondary else {
            return
        }

        secondary.codeSnippet = CodeSnippets.cached.snippets[indexPath.row]
        splitViewController?.showDetailViewController(secondary, sender: self)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}
