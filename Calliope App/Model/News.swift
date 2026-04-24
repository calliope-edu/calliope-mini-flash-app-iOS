//
//  NewsItem.swift
//  Calliope App
//
//  Created by Tassilo Karge on 30.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit
import SwiftUI

protocol NewsItemProtocol {
    var text: String { get set }
    var url: URL { get set }
    var color: String? { get set }
    var textcolor: String? { get set }

    func loadImage(_ completion: @escaping (Result<UIImage, Error>) -> ())
}

struct NewsManager {
	static func getNews(_ completion: @escaping (Result<[NewsItem], Error>) -> ()) {

		#if DEBUG
		URLCache.shared.removeAllCachedResponses()
		#endif

        var urlString = UserDefaults.standard.string(forKey: SettingsKey.newsURL.rawValue)
        let defaultUrlString = Settings.defaultNewsUrl
        if urlString == nil {
            urlString = defaultUrlString
        }
        guard let url = URL(string: urlString!) else {
            completion(.failure("news url not valid"))
            return
        }
		let task = URLSession.shared.dataTask(with: url) {data, response, error in
			let result: [NewsItem]?
			if error == nil, let data = data {
				let decoder = JSONDecoder()
                let apiNewsItems = try? decoder.decode([APINewsItem].self, from: data)
                result = apiNewsItems != nil ? (apiNewsItems! as [APINewsItem]).map{ apiNewsItem in apiNewsItem.toNewsItem() } : nil
			} else {
				result = nil
			}
			completion(result != nil ? .success(result!) : .failure(error ?? "Could not find news"))
		}
		task.resume()
	}

	static func getDefaultNews() -> [NewsItem] {
        return [NewsItem(tileItem: TileItem(title: "No Internet", imageSource: ImageSource.local("AnimError/0015"), color: Color(hex: "#8073E5")!, textColor: Color(hex: "#68D5D5")!), url: "http://calliope.cc")]
        //color: #colorLiteral(red: 0.5019999743, green: 0.451000005, blue: 0.8980000019, alpha: 1).hex, textcolor: #colorLiteral(red: 0.4079999924, green: 0.8309999704, blue: 0.8309999704, alpha: 1).hex
	}
}

struct APINewsItem: Codable {
    var image: URL?
    var text: String
    var url: URL
    var color: String?
    var textcolor: String?
    
    func toNewsItem() -> NewsItem {
        let imageSource = image != nil ? ImageSource.remote(image!) : ImageSource.local("AnimError/0015")
        let swiftUIColor = color.flatMap { Color(hex: $0) } ?? Color("calliope-pink")
        let swiftUITextColor = textcolor.flatMap { Color(hex: $0) } ?? Color(.black)
        return NewsItem(tileItem: TileItem(title: text, imageSource: imageSource, color: swiftUIColor, textColor: swiftUITextColor), url: url.absoluteString)
    }
}

struct NewsItemWithStaticImage: NewsItemProtocol {
    var image: UIImage?
    var text: String
    var url: URL
    var color: String?
    var textcolor: String?

    func loadImage(_ completion: @escaping (Result<UIImage, Error>) -> ()) {
        guard let image = image else {
            completion(.success(#imageLiteral(resourceName: "teaser_noInternet.pdf")))
            return
        }
        completion(.success(image))
    }
}
