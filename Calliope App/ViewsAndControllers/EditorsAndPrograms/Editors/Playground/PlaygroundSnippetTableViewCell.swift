//
//  PlaygroundSnippetTableViewCell.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.01.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import UIKit

class PlaygroundSnippetTableViewCell: UITableViewCell {

    @IBOutlet weak var copySuccessOverlay: UIVisualEffectView!

    var snippet: CodeSnippet? {
        didSet {
            snippetTitle.text = snippet?.title ?? ""
            summary.text = snippet?.summary ?? ""
            code?.attributedText = PlaygroundSnippetTableViewCell.codeSnippetHighlighter.codeSnippetToAttributedString(snippet)
        }
    }

    @IBOutlet weak var snippetTitle: UILabel!
    @IBOutlet weak var summary: UILabel!
    @IBOutlet weak var code: UILabel?

    static let codeSnippetHighlighter = SwiftCodeSnippetHighlighter()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func copyCode() {
        guard let codeSnippet = snippet else {
            return
        }
        UIPasteboard.general.string = codeSnippet.content
        copySuccessOverlay.isHidden = false
        UIView.animate(withDuration: 0.4) {
            self.copySuccessOverlay.effect = UIBlurEffect(style: .regular)
        } completion: { done in
            if done {
                UIView.animateKeyframes(withDuration: 0.2, delay: 1.0) {
                    self.copySuccessOverlay.effect = nil
                } completion: { done in
                    if done {
                        self.copySuccessOverlay.isHidden = true
                    }
                }
            }
        }
    }
}
