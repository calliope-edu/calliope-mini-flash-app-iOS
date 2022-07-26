//
//  PageIndicatorContainingViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class PageIndicatorContainingViewController: UIViewController {

    var pages: [String] = []

    @IBOutlet weak var pageIndicator: UIImageView!

    required init?(coder: NSCoder, pages: [String]) {
        self.pages = pages
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        if #available(iOS 13.0, *) {
            fatalError("init with coder for onboardingcontroller not implemented in ios13")
        }
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
    }

    // MARK: - Navigation
    
    @IBSegueAction func makeOnboardingPageViewController(_ coder: NSCoder) -> OnboardingViewController? {
        let vc = OnboardingViewController(coder: coder, pageIndicator: self.pageIndicator, pages: self.pages)
        return vc
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if #available(iOS 13.0, *) { return } // will use makeOnboardingPageViewController
        if let vc = segue.destination as? OnboardingViewController,
           segue.identifier == "embedPageVC" {
            vc.pageIndicator = self.pageIndicator
            vc.pages = self.pages
        }
    }

}
