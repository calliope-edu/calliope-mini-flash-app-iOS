//
//  TextFieldView.swift
//  Calliope
//
//  Created by Benedikt Spohr on 1/27/19.
//

import UIKit
import SnapKit

/// A colored view that contains a title, subtitle and icon
class ButtonView: UIView {
    
    // MARK: - UIElements
    private let topLayoutView = UIView()
    private let titleLabel = UILabel()
    private let separatorView = UIView()
    private let bottomLayoutView = UIView()
    private let subtitleLabel = UILabel()
    private let iconImageView = UIImageView()
    
    // Mark: - Vars
    private let didPressed: (() -> Void)
    
    // MARK: - Lifecycle
    
    /// Creates a new instance
    ///
    /// - Parameters:
    ///   - title: String displayed above the separator
    ///   - subtitle: String displayed below the separator
    ///   - icon: image will be displayed beside the subtitle label
    ///   - color: background color od the view
    ///   - didPressed: called when the view get pressed
    init(title: String,
         subtitle: String,
         icon: UIImage?,
         color: UIColor,
         didPressed: @escaping (() -> Void)) {
        self.didPressed = didPressed
        super.init(frame: CGRect.null)
        titleLabel.text = title
        subtitleLabel.text = subtitle
        iconImageView.image = icon
        backgroundColor = color
        setup()
        layout()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        // View
        layer.cornerRadius = range(8...20)
        let tapGestureRec = UITapGestureRecognizer(target: self, action: #selector(didPressedView))
        addGestureRecognizer(tapGestureRec)
        // TitleLabel
        titleLabel.font = Styles.defaultFont(size: range(15...35))
        titleLabel.textColor = Styles.colorWhite
        // Separator
        separatorView.backgroundColor = .white
        // SubtitleLabel
        subtitleLabel.font = Styles.defaultFont(size: range(15...35))
        subtitleLabel.textColor = Styles.colorWhite
        // IconImageView
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = Styles.colorWhite
    }
    
    private func layout() {
        // Top View
        addSubview(topLayoutView)
        topLayoutView.snp.makeConstraints { (make) in
            make.left.top.right.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.5)
        }
        topLayoutView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(range(16,32))
            make.right.greaterThanOrEqualToSuperview().offset(range(-20, -40))
        }
        // Separator
        addSubview(separatorView)
        separatorView.snp.makeConstraints { (make) in
            make.centerX.centerY.equalToSuperview()
            make.height.equalTo(1)
            make.left.equalToSuperview().offset(range(16, 40))
            make.right.equalToSuperview().offset(range(-16, -40))
        }
        // BottomView
        addSubview(bottomLayoutView)
        bottomLayoutView.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.5)
        }
        // IconsImageView
        bottomLayoutView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview()
            make.height.width.equalTo(bottomLayoutView.snp.height).multipliedBy(0.5)
        }
        // SubtitleLabel
        bottomLayoutView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.left.equalTo(iconImageView.snp.right).offset(range(16, 40))
            make.right.equalToSuperview()
        }
    }
    
    // MARK: - TextFieldDelegate
    @objc func didPressedView() {
        didPressed()
    }
}

