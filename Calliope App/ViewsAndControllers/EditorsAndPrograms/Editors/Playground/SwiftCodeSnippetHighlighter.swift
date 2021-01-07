//
//  SwiftCodeHighlighter.swift
//  Calliope App
//
//  Created by Tassilo Karge on 06.01.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import Foundation
import Highlightr

public struct SwiftCodeSnippetHighlighter {

    static let defaultCodeSize: CGFloat = 16

    static let regularCodeFont = Styles.scaledFont(Styles.defaultRegularFont(size: defaultCodeSize, mono: true), for: .body)
    static let boldCodeFont = Styles.scaledFont(Styles.defaultBoldFont(size: defaultCodeSize, mono: true), for: .body)

    let highlightr: Highlightr? = {
        guard let hl = Highlightr() else {
            //highlightr does not work for some reason
            LogNotify.log("highlightr could not be instanciated")
            return nil
        }

        hl.setTheme(to: "xcode")
        //hl.setTheme(to: "school-book")
        hl.theme.boldCodeFont = boldCodeFont
        hl.theme.codeFont = regularCodeFont

        return hl
    }()

    public func codeSnippetContentToAttributedString(_ codeSnippet: String) -> NSAttributedString? {
        guard let code = NSMutableString(utf8String: codeSnippet) else {
            return nil
        }

        //replace placeholders with different markers to avoid parser confusion

        //replace with the first pattern part for highlighted and with default for not highlighted code
        // e.g. <#T##codeSnippet: String##String# (closing angle bracket)
        let typeWithDefaultPlaceholderPattern = highlightr != nil
            ? "\\<\\#T\\#\\#(.*?)\\#\\#.*?\\#\\>"
            : "\\<\\#T\\#\\#.*?\\#\\#(.*?)\\#\\>"

        // e.g. <#T##String# (closing angle bracket)
        let typePlaceholderPattern = "\\<\\#T\\#\\#(.*?)\\#\\>"

        // e.g. <#code# (closing angle bracket)
        let placeholderPattern = "\\<\\#(.*?)\\#\\>"

        let orderedPatterns = [typeWithDefaultPlaceholderPattern, typePlaceholderPattern, placeholderPattern]

        for pattern in orderedPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                regex.replaceMatches(in: code, options: [], range: NSMakeRange(0, code.length), withTemplate: "___$1___")
            }
        }

        let highlighted: NSMutableAttributedString
        if let highlightr = highlightr {
            highlighted = NSMutableAttributedString(attributedString: highlightr.highlight(String(code), as: "swift") ?? NSAttributedString())
        } else {
            highlighted = NSMutableAttributedString(string: code as String)
            highlighted.addAttribute(.font, value: SwiftCodeSnippetHighlighter.regularCodeFont, range: NSMakeRange(0, code.length))
        }

        //set style of marked areas to indicate that there will be a replacement
        if let regex = try? NSRegularExpression(pattern: "___.*?___", options: []) {
            let matches = regex.matches(in: highlighted.string, options: [], range: NSMakeRange(0, code.length)).reversed()
            for match in matches {
                let range = match.range
                highlighted.addAttribute(.backgroundColor, value: UIColor.gray, range: match.range)
                highlighted.deleteCharacters(in: NSMakeRange(range.upperBound - 3, 3))
                highlighted.deleteCharacters(in: NSMakeRange(range.lowerBound, 3))
            }
        }

        return highlighted
    }
}
