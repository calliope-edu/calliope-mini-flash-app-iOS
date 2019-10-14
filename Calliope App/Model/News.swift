//
//  NewsItem.swift
//  Calliope App
//
//  Created by Tassilo Karge on 30.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

struct NewsManager {
	static func getNews(_ completion: @escaping (Result<[NewsItem], Error>) -> ()) {

		#if DEBUG
		URLCache.shared.removeAllCachedResponses()
		#endif

		let url = URL(string: UserDefaults.standard.string(forKey: SettingsKey.newsURL.rawValue)!)!
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

	static func getDefaultNews() -> [NewsItem] {
		return [NewsItem(image: nil, text: "Happy Coding", url: URL(string: "http://calliope.cc")!, color: #colorLiteral(red: 0.5019999743, green: 0.451000005, blue: 0.8980000019, alpha: 1).hex, textcolor: #colorLiteral(red: 0.4079999924, green: 0.8309999704, blue: 0.8309999704, alpha: 1).hex)]
        //color: #colorLiteral(red: 0.5019999743, green: 0.451000005, blue: 0.8980000019, alpha: 1).hex, textcolor: #colorLiteral(red: 0.4079999924, green: 0.8309999704, blue: 0.8309999704, alpha: 1).hex
	}
}

struct NewsItem: Codable {
	var image: URL?
	var text: String
	var url: URL
	var color: String?
    var textcolor: String?

	func loadImage(_ completion: @escaping (Result<UIImage, Error>) -> ()) {
		guard let imageUrl = image else {
			completion(.success(#imageLiteral(resourceName: "AnimSuccess/0018")))
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
