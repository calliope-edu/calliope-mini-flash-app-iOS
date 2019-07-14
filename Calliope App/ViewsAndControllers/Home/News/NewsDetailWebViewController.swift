//
//  NewsDetailWebViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 30.06.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit
import WebKit

class NewsDetailWebViewController: UIViewController {

	@IBOutlet weak var webView: WKWebView!

	public var url: URL!

    override func viewDidLoad() {
        super.viewDidLoad()

		webView.load(URLRequest(url: url))
        // Do any additional setup after loading the view.
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
