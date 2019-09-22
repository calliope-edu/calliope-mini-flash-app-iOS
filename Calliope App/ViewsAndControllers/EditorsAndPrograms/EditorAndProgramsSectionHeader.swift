//
//  EditorAndProgramsSectionHeader.swift
//  Calliope App
//
//  Created by Tassilo Karge on 22.09.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class EditorAndProgramsSectionHeader: UICollectionReusableView {
        
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var resetButton: UIButton! {
        didSet { resetButton.isHidden = false }
    }
    @IBOutlet weak var hideButtonConstraint: NSLayoutConstraint! {
        didSet { hideButtonConstraint.isActive = false }
    }
    
    var buttonHidden: Bool {
        set {
            resetButton.isHidden = newValue
            hideButtonConstraint.isActive = newValue
        }
        get { return resetButton.isHidden }
    }
    
    var titleText: String? {
        set { title.text = newValue }
        get { return title.text }
    }
}
