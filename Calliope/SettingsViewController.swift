//
//  SettingsViewController.swift
//  Calliope
//
//  Created by Benedikt Spohr on 1/24/19.
//

import UIKit
import SnapKit
import TPKeyboardAvoiding

/// View Controller that allows the user to change the preselted url to the editor websites
///
/// Needs an UINavigationController to show BarButtonItems
/// ScrollView is needed to scroll views while keyboard is shown
class SettingsViewController: UIViewController {
    // MARK: - UIElements
    let scrollView = TPKeyboardAvoidingScrollView()
    let scrollContentView = UIView()
    // BarButtons
    private var saveButton: UIBarButtonItem!
    private var cancelButton: UIBarButtonItem!
    private var restoreButton: UIBarButtonItem!
    // Colored views
    var robertaView: UIView!
    var makeCodeView: UIView!
    var calliopeView: UIView!
    
    // MARK: - Vars
    var editedCalliopeUrl: String?
    var editedMakeCodeUrl: String?
    var editedRobertaUrl: String?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setBarButtons()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layout()
    }
    
    // MARK: - Setup
    private func setup() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            title = "settings.settings".localized
        }
        editedRobertaUrl = URLManager.robertaUrl
        editedMakeCodeUrl = URLManager.makeCodeUrl
        editedCalliopeUrl = URLManager.calliopeUrl
        view.backgroundColor = .white
    }
    
    
    private func layout() {
        // Constants
        var height = view.frame.height
        if  #available(iOS 11.0, *) {
            if let safeAreaInsets = presentingViewController?.view.safeAreaInsets {
                height -= (safeAreaInsets.top +
                    safeAreaInsets.bottom +
                    (navigationController?.navigationBar.frame.height ?? 0.0))
            }
        }
        //SCrollView
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) in
            make.top.right.bottom.left.equalToSuperview()
        }
        scrollView.addSubview(scrollContentView)
        scrollContentView.snp.makeConstraints { (make) in
            make.top.right.bottom.left.equalToSuperview()
            make.width.equalTo(view)
            make.height.equalTo(height)
        }
        // OpenROberta
        robertaView = TextFieldView(title: "Open Roberta NEPO®",
                                        color: Styles.colorBlue,
                                        text: URLManager.robertaUrl ?? "") {[weak self] (text) in
                                            self?.editedRobertaUrl = text
        }
        scrollContentView.addSubview(robertaView)
        
        robertaView.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview().offset(range(-8, -32))
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.9)
            make.height.equalToSuperview().multipliedBy(0.25)
        }
        // MakeCode
        makeCodeView = TextFieldView(title: "MakeCode",
                                         color: Styles.colorGreen,
                                         text: URLManager.makeCodeUrl ?? "") { [weak self] (text) in
                                            self?.editedMakeCodeUrl = text
        }
        scrollContentView.addSubview(makeCodeView)
        makeCodeView.snp.makeConstraints { (make) in
            make.bottom.equalTo(robertaView.snp.top).offset(range(-8, -32))
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.9)
            make.height.equalToSuperview().multipliedBy(0.25)
        }
        // Colliop
        calliopeView = TextFieldView(title: "Colliope mini Editor",
                                 color: Styles.colorYellow,
                                 text: URLManager.calliopeUrl ?? "") { [weak self] (text) in
                                    self?.editedCalliopeUrl = text
        }
        scrollContentView.addSubview(calliopeView)
        calliopeView.snp.makeConstraints { (make) in
            make.bottom.equalTo(makeCodeView.snp.top).offset(range(-8, -32))
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.9)
            make.height.equalToSuperview().multipliedBy(0.25)
        }
    }
    
    private func setBarButtons() {
        saveButton = UIBarButtonItem(title: "settings.save".localized,
                                     style: .done,
                                     target: self,
                                     action: #selector(savePressed))
        cancelButton = UIBarButtonItem(title: "settings.canel".localized,
                                       style: .done,
                                       target: self,
                                       action: #selector(cancelPressed))
        restoreButton = UIBarButtonItem(title: "settings.restore".localized,
                                        style: .done,
                                        target: self,
                                        action: #selector(restorePressed))
        navigationItem.rightBarButtonItem = saveButton
        navigationItem.leftBarButtonItems = [cancelButton, restoreButton]
    }
    // MARK: - IBActions
    @objc private func savePressed() {
        URLManager.save(calliope: editedCalliopeUrl,
                   makeCode: editedMakeCodeUrl,
                   roberta: editedRobertaUrl)
        navigationController?.dismiss(animated: true, completion: nil)
    }
    @objc private func cancelPressed() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @objc private func restorePressed() {
        URLManager.restoreValues()
        navigationController?.dismiss(animated: true, completion: nil)
    }
}
