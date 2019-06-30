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
}

struct NewsItem: Codable {
	var image: URL
	var text: String
	var url: URL

	func loadImage(_ completion: @escaping (Result<UIImage, Error>) -> ()) {
		let task = URLSession.shared.dataTask(with: image) {data, response, error in
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
