//
//  CodeSnippet.swift
//  Calliope App
//
//  Created by Tassilo Karge on 02.01.21.
//  Copyright © 2021 calliope. All rights reserved.
//

import Foundation
import UIKit

struct CodeSnippets {

    static var cached: CodeSnippets = CodeSnippets(snippets: [])

    var snippets: [CodeSnippet]

    static func reload(failure: @escaping (Error?) -> (), completion: @escaping () -> ()) {

        var urlString = UserDefaults.standard.string(forKey: SettingsKey.arcadeUrl.rawValue)
        let defaultUrlString = Settings.defaultArcadeUrl
        if urlString == nil {
            urlString = defaultUrlString
        }
        guard let url = URL(string: urlString!) else {
            LogNotify.log("snippets url not valid")
            return
        }

        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            let decoder = JSONDecoder()
            guard error == nil, let data = data else {
                LogNotify.log("no data found in \(url), error: \(error ?? "none")")
                failure(error)
                return
            }
            let urls: [URL]
            do {
                urls = try decoder.decode([URL].self, from: data)
            } catch {
                LogNotify.log("no valid json in \(url), error: \(error)")
                failure(error)
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
