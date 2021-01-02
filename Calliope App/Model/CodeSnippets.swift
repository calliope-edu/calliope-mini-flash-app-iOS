//
//  CodeSnippet.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.01.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import Foundation

struct CodeSnippets {

    static var cached: CodeSnippets = CodeSnippets(snippets: [])

    var snippets: [CodeSnippet]

    static func reload(_ completion: @escaping () -> ()) {

        var urlString = UserDefaults.standard.string(forKey: SettingsKey.playgroundTemplateUrl.rawValue)
        let defaultUrlString = Settings.defaultPlaygroundTemplateUrl
        if urlString == nil || urlString! == defaultUrlString {
            urlString = defaultUrlString.localized
        }
        guard let url = URL(string: urlString!) else {
            LogNotify.log("snippets url not valid")
            return
        }

        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            let decoder = JSONDecoder()
            guard error == nil, let data = data, let urls = try? decoder.decode([URL].self, from: data) else {
                LogNotify.log("no URL json found in \(url), error: \(error ?? "none")")
                return
            }

            var collectedSnippets: [CodeSnippet] = []

            DispatchQueue.global(qos: .userInitiated).async {
                for url in urls {
                    guard let data = try? Data(contentsOf: url) else {
                        continue
                    }
                    let plistDecoder = PropertyListDecoder()
                    if let snippet = try? plistDecoder.decode(IDECodeSnippet.self, from: data) {
                        collectedSnippets.append(snippet.toCodeSnippet())
                    }
                }

                LogNotify.log("Downloaded \(collectedSnippets.count) snippets")
                CodeSnippets.cached = CodeSnippets(snippets: collectedSnippets)
                completion()
            }
        }

        dataTask.resume()
    }
}

public struct CodeSnippet: Codable {
    let completionScopes: [String]
    let content: String
    let summary: String
    let title: String
}

struct IDECodeSnippet: Codable {
    let IDECodeSnippetCompletionPrefix: String?
    let IDECodeSnippetCompletionScopes: [String]?
    let IDECodeSnippetContents: String?
    let IDECodeSnippetIdentifier: String?
    let IDECodeSnippetLanguage: String?
    let IDECodeSnippetPlatformFamily: String?
    let IDECodeSnippetSummary: String?
    let IDECodeSnippetTitle: String?
    let IDECodeSnippetUserSnippet: Bool?
    let IDECodeSnippetVersion: Int?

    func toCodeSnippet() -> CodeSnippet {
        CodeSnippet(completionScopes: IDECodeSnippetCompletionScopes ?? [], content: IDECodeSnippetContents ?? "", summary: IDECodeSnippetSummary ?? "", title: IDECodeSnippetTitle ?? "")
    }
}
