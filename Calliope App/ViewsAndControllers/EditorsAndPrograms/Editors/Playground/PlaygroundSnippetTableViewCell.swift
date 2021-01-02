//
//  PlaygroundSnippetTableViewCell.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.01.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

class PlaygroundSnippetTableViewCell: UITableViewCell {

    var snippet: CodeSnippet? {
        didSet {
            snippetTitle.text = snippet?.title ?? ""
            summary.text = snippet?.summary ?? ""
        }
    }

    @IBOutlet weak var snippetTitle: UILabel!
    @IBOutlet weak var summary: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
