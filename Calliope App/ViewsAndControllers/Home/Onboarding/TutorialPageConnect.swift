//
//  TutorialConnectViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageConnect: TutorialPageViewController {
    
    let unconnectedText = "Push the button and follow the instructions for connecting to your Calliope"
    let succeededText = "You are connected to your Calliope, well done!"
    
    @IBOutlet weak var arrowImageView: UIImageView!
    
    @IBOutlet weak var instructionLabel: UILabel!
    
    var hasConnected: Bool {
        return MatrixConnectionViewController.instance.usageReadyCalliope != nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if traitCollection.layoutDirection == .rightToLeft {
            arrowImageView.image = UIImage(named: "arrows/arrow-top")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setText()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delay(time: 0.5) {
            self.animateBounce()
        }
    }
    
    
    @IBAction override func nextPage(_ sender: Any) {
        setText()
        if hasConnected {
            delay(time: 0.8) {
                self.delegate?.proceed(from: self, completed: true)
            }
        }
        self.animateBounce()
    }
    
    override func attemptProceed() -> (Bool, Bool) {
        self.animateBounce()
        if hasConnected {
            return (true, true)
        } else {
            return (false, false)
        }
    }
    
    private func animateBounce() {
        guard !hasConnected else { return }
        
        let originalTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0);
        UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseOut, animations: {
            self.arrowImageView.transform = originalTransform.scaledBy(x: 1.5, y: 1.5)
            self.view.layoutIfNeeded()
        }) { _ in
            UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: .curveEaseIn, animations: {
                self.arrowImageView.transform = originalTransform
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    private func setText() {
        UIView.animate(withDuration: 0.2) {
            if self.hasConnected {
                self.instructionLabel.text = self.succeededText
            } else {
                self.instructionLabel.text = self.unconnectedText
            }
        }
    }
}
