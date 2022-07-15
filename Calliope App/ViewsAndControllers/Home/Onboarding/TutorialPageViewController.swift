//
//  TutorialViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageViewController: UIViewController, OnboardingPage {
    var delegate: OnboardingPageDelegate?
    
    func attemptProceed() -> (Bool, Bool) {
        return (true, true)
    }
    

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
    }
    
    @IBAction func nextPage(_ sender: Any) {
        self.delegate?.proceed(from: self, completed: true)
    }
}
