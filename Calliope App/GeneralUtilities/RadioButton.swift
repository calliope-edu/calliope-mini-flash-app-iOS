//
//  RadioButton.swift
//  Calliope App
//
//  Created by itestra on 02.07.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class RadioButton: UIButton {
    var alternateButton:Array<RadioButton>?
    
    override func awakeFromNib() {
        self.layer.cornerRadius = 5
        self.layer.borderWidth = 2.0
        self.layer.masksToBounds = true
        self.layer.backgroundColor = UIColor.calliopeTurqoise.cgColor
    }
    
    func unselectAlternateButtons() {
        if alternateButton != nil {
            self.isSelected = true
            
            for aButton:RadioButton in alternateButton! {
                aButton.isSelected = false
            }
        } else {
            toggleButton()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        unselectAlternateButtons()
        super.touchesBegan(touches, with: event)
    }
    
    func toggleButton() {
        self.isSelected = !isSelected
    }
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                self.layer.borderColor = UIColor.calliopeTurqoise.cgColor
            } else {
                self.layer.borderColor = UIColor.calliopeGray.cgColor
            }
        }
    }
}
