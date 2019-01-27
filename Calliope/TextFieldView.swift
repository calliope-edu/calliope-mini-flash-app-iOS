//
//  TextFieldView.swift
//  Calliope
//
//  Created by Benedikt Spohr on 1/24/19.
//

import UIKit
import SnapKit

/// A colored view that contains a textField and a title
class TextFieldView: UIView {
    
    // MARK: - UIElements
    private let topLayoutView = UIView()
    private let titleLabel = UILabel()
    private let separatorView = UIView()
    private let bottomLayoutView = UIView()
    private let textField = UITextField()
    
    // Mark: - Vars
    private let title: String
    private var text: String
    private let textDidChange: ((String) -> Void)
    
    // MARK: - Lifecycle
    init(title: String, color: UIColor, text: String, textDidChange: @escaping ((String) -> Void)) {
        self.title = title
        self.text = text
        self.textDidChange = textDidChange
        super.init(frame: CGRect.null)
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
        // TitleLabel
        titleLabel.text = title
        titleLabel.font = Styles.defaultFont(size: range(15...35))
        titleLabel.textColor = Styles.colorWhite
        // Separator
        separatorView.backgroundColor = .white
        // TextField
        textField.textContentType = UITextContentType.URL
        textField.layer.cornerRadius = range(8...20)
        textField.text = text
        textField.borderStyle = .roundedRect
        textField.font = Styles.defaultFont(size: range(15...25))
        textField.textColor = Styles.colorGray
        textField.addTarget(self, action: #selector(self.didChangeText(for:)), for: .allEvents)
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
            make.left.equalToSuperview().offset(range(20...40))
            make.right.greaterThanOrEqualToSuperview().offset(range(-20, -40))
        }
        // Separator
        addSubview(separatorView)
        separatorView.snp.makeConstraints { (make) in
            make.centerX.centerY.equalToSuperview()
            make.height.equalTo(1)
            make.left.equalToSuperview().offset(range(20...40))
            make.right.greaterThanOrEqualToSuperview().offset(range(-20, -40))
        }
        // BottomView
        addSubview(bottomLayoutView)
        bottomLayoutView.snp.makeConstraints { (make) in
            make.left.bottom.right.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.5)
        }
        bottomLayoutView.addSubview(textField)
        textField.snp.makeConstraints { (make) in
            make.centerX.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(range(20...40))
            make.right.greaterThanOrEqualToSuperview().offset(range(-20, -40))
        }
    }
    
    // MARK: - TextFieldDelegate
    @objc func didChangeText(for textField: UITextField) {
        textDidChange(textField.text ?? "")
    }
}

