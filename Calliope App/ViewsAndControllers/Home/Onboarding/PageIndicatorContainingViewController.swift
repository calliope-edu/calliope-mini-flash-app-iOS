//
//  PageIndicatorContainingViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class PageIndicatorContainingViewController: UIViewController {

    @IBOutlet weak var pageIndicator: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    

    // MARK: - Navigation
    
    @IBSegueAction func makeOnboardingPageViewController(_ coder: NSCoder) -> OnboardingViewController? {
        return OnboardingViewController(coder: coder, pageIndicator: self.pageIndicator)
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if #available(iOS 13.0, *) { return }
        if segue.identifier == "embedPageVC" {
            (segue.destination as! OnboardingViewController).pageIndicator = self.pageIndicator
        }
    }

}
