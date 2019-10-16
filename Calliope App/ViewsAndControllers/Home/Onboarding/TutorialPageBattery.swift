//
//  TutorialPageBattery.swift
//  Calliope App
//
//  Created by Tassilo Karge on 15.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageBattery: TutorialPageViewController {
    
    @IBOutlet weak var instructionSlideshowImage: UIImageView!
    
    private let images = [#imageLiteral(resourceName: "insert_battery_00"), #imageLiteral(resourceName: "insert_battery_01.pdf"), #imageLiteral(resourceName: "insert_battery_02.pdf"), #imageLiteral(resourceName: "insert_battery_03.pdf"), #imageLiteral(resourceName: "insert_battery_04")]
    
    private var imageIndex = 0
    private var slideshowRunning: Bool = false
    
    override func viewDidLoad() {
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
}
