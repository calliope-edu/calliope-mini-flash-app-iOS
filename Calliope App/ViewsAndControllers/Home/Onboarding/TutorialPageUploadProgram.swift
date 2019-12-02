//
//  TutorialPageUploadProgramViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.11.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageUploadProgram: TutorialPageViewController {
    @IBOutlet weak var blinkingHeart: UIImageView!
    
    override func viewDidLoad() {
        let images = [#imageLiteral(resourceName: "ani_heart_00.pdf"), #imageLiteral(resourceName: "ani_heart_01.pdf"), #imageLiteral(resourceName: "ani_heart_02.pdf"), #imageLiteral(resourceName: "ani_heart_03.pdf")]
        blinkingHeart.animationImages = images
        blinkingHeart.animationDuration = 0.3 * Double(images.count)
        blinkingHeart.startAnimating()
    }
    
    @IBAction func uploadProgram(_ sender: Any) {
        let program = BlinkingHeartProgram.blinkingHeartProgram
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program, name: "Blinking Heart")
    }
}
