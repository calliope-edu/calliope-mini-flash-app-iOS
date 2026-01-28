//
//  NewsItem.swift
//  Calliope App
//
//  Created by Tassilo Karge on 30.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

protocol NewsItemProtocol {
    var text: String { get set }
    var url: URL { get set }
    var color: String? { get set }
    var textcolor: String? { get set }

    func loadImage(_ completion: @escaping (Result<UIImage, Error>) -> ())
}

struct NewsManager {
	static func getNews(_ completion: @escaping (Result<[NewsItemProtocol], Error>) -> ()) {

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
				result = try? decoder.decode([NewsItem].self, from: data)
			} else {
				result = nil
			}
			completion(result != nil ? .success(result!) : .failure(error ?? "Could not find news"))
		}
		task.resume()
	}

	static func getDefaultNews() -> [NewsItemProtocol] {
		return [NewsItemWithStaticImage(image: #imageLiteral(resourceName: "teaser_noInternet.pdf"), text: "No Internet", url: URL(string: "http://calliope.cc")!, color: #colorLiteral(red: 0.5019999743, green: 0.451000005, blue: 0.8980000019, alpha: 1).hex, textcolor: #colorLiteral(red: 0.4079999924, green: 0.8309999704, blue: 0.8309999704, alpha: 1).hex)]
        //color: #colorLiteral(red: 0.5019999743, green: 0.451000005, blue: 0.8980000019, alpha: 1).hex, textcolor: #colorLiteral(red: 0.4079999924, green: 0.8309999704, blue: 0.8309999704, alpha: 1).hex
	}
}

struct NewsItem: NewsItemProtocol, Codable {
	var image: URL?
	var text: String
	var url: URL
	var color: String?
    var textcolor: String?

	func loadImage(_ completion: @escaping (Result<UIImage, Error>) -> ()) {
		guard let imageUrl = image else {
			completion(.success(#imageLiteral(resourceName: "teaser_noInternet.pdf")))
			return
		}
		let task = URLSession.shared.dataTask(with: imageUrl) {data, response, error in
			let result: UIImage?
			if error == nil, let data = data {
				result = UIImage(data: data)
			} else {
				result = nil
			}
			completion(result != nil ? .success(result!) : .failure(error ?? "Could not decode image"))
		}
		task.resume()
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
