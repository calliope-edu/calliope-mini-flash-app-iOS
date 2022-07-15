//
//  TutorialPageBattery.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageBattery: UIViewController {
    
    @IBOutlet weak var instructionSlideshowImage: UIImageView!
    
    private let images = [#imageLiteral(resourceName: "insert_battery_00"), #imageLiteral(resourceName: "insert_battery_01.pdf"), #imageLiteral(resourceName: "insert_battery_02.pdf"), #imageLiteral(resourceName: "insert_battery_03.pdf"), #imageLiteral(resourceName: "insert_battery_04")]
    
    private var imageIndex = 0
    private var slideshowRunning: Bool = false
    
    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        slideshowRunning = true
        showNextImage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        slideshowRunning = false
    }

    func showNextImage() {
        guard slideshowRunning else { return }
        UIView.transition(with: instructionSlideshowImage, duration: 0.5, options: .transitionCrossDissolve, animations: {
            self.instructionSlideshowImage.image = self.images[self.imageIndex]
        }) { (_) in
            self.imageIndex = (self.imageIndex + 1) % self.images.count
            delay(time: 2.0) { [weak self] in
                self?.showNextImage()
            }
        }
    }

    //MARK: transition to page view controller

    var pagesStartProgram = ["tutorial_mini_demo", "tutorial_menu"]
    var pagesUpload = ["tutorial_connect_bluetooth", "tutorial_upload_program"]

    @IBSegueAction func openStartProgramTutorial(_ coder: NSCoder) -> PageIndicatorContainingViewController? {
        return PageIndicatorContainingViewController(coder: coder, pages: pagesStartProgram)
    }

    @IBSegueAction func openUploadTutorial(_ coder: NSCoder) -> PageIndicatorContainingViewController? {
        return PageIndicatorContainingViewController(coder: coder, pages: pagesUpload)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if #available(iOS 13.0, *) { return } // will use open...Tutorial methods

        guard let vc = segue.destination as? OnboardingViewController else {
            return
        }

        if segue.identifier == "showStartProgramPages" {
            vc.pages = pagesStartProgram
        } else if segue.identifier == "showUploadPages" {
            vc.pages = pagesUpload
        }
    }
}
