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
        super.viewDidLoad()
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
