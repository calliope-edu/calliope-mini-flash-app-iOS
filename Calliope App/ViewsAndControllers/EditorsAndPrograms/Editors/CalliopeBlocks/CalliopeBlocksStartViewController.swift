//
//  CalliopeBlocksStartViewController.swift
//  Calliope App
//
//  Created by itestra GmbH on 04.04.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import UIKit

class CalliopeBlocksStartViewController: UIViewController {

    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var appStoreImageView: UIImageView!
    @IBOutlet weak var calliopeBlocksImageView: UIImageView!
    @IBOutlet weak var connectionImageView: UIImageView!
    @IBOutlet weak var scratchInformationFooterLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appStoreTabGesture1 = UITapGestureRecognizer(target: self, action: #selector(self.openLinkToAppStorePage(gesture:)))
        let appStoreTabGesture2 = UITapGestureRecognizer(target: self, action: #selector(self.openLinkToAppStorePage(gesture:)))
        appStoreImageView.addGestureRecognizer(appStoreTabGesture1)
        appStoreImageView.isUserInteractionEnabled = true
        calliopeBlocksImageView.addGestureRecognizer(appStoreTabGesture2)
        calliopeBlocksImageView.isUserInteractionEnabled = true
        
        let attributedString = NSMutableAttributedString(string: "Scratch is a project of the Scratch Foundation, in collaboration with the Lifelong Kindergarten Group at the MIT Media Lab. It is available for free at https://scratch.mit.edu.")
        attributedString.addAttribute(.link, value: "", range: NSRange(location: 151, length: 24))
        scratchInformationFooterLabel.attributedText = attributedString
        scratchInformationFooterLabel.isUserInteractionEnabled = true
        
        let linkToScratchTapGesture = UITapGestureRecognizer(target: self, action: #selector(openLinkToScratch(_:)))
        scratchInformationFooterLabel.addGestureRecognizer(linkToScratchTapGesture)
        
        connectionImageView.layer.masksToBounds = false
        connectionImageView.layer.shadowColor = UIColor.darkGray.cgColor
        connectionImageView.layer.shadowOpacity = 0.5
        connectionImageView.layer.shadowOffset = CGSize(width: 0, height: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rearrangeStackview(view.bounds.size)
        MatrixConnectionViewController.instance?.calliopeClass = DiscoveredBLEDDevice.self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.rearrangeStackview(view.bounds.size)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { (_) in
            self.rearrangeStackview(size)
        }, completion: nil)
    }

    private func rearrangeStackview(_ size: CGSize) {
        let landscape: Bool = size.width > size.height
        mainStackView.axis = landscape ? .horizontal : .vertical
    }

    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        let landscape: Bool = parentSize.width > parentSize.height
        return CGSize(width: landscape ? parentSize.width / 2.0 : parentSize.width, height: landscape ? parentSize.height : parentSize.height / 2.0)
    }
    
    @objc func openLinkToAppStorePage(gesture: UIGestureRecognizer) {
        if let url = URL(string: "https://apps.apple.com/de/app/calliope-mini-blocks/id6480199471") {
            UIApplication.shared.open(url)
        }
    }
    
    @objc func openLinkToScratch(_ gesture: UITapGestureRecognizer) {
        if let url = URL(string: "https://scratch.mit.edu") {
            UIApplication.shared.open(url)
        }
    }
    
    /// URL scheme of the Calliope mini Blocks app used to launch it directly.
    /// Update this value if the app registers a different custom URL scheme.
    private let calliopeBlocksAppURLScheme = "scrub://"

    @IBAction func openLinkToCalliopeBlocksGetStatedPage(_ sender: Any) {
        // 1. Reset the saved bluetooth pattern so the connection button starts blank
        let blankMatrix = String(repeating: "0", count: 25)
        UserDefaults.standard.set("", forKey: SettingsKey.lastMatrix.rawValue)
        if let connectionVC = MatrixConnectionViewController.instance {
            connectionVC.matrixView.setMatrixString(pattern: blankMatrix)
            connectionVC.matrixView.updateBlock()
        }

        // 2. Open the Calliope mini Blocks app; fall back to the App Store if not installed
        if let appURL = URL(string: calliopeBlocksAppURLScheme),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let storeURL = URL(string: "https://apps.apple.com/app/id6480199471") {
            UIApplication.shared.open(storeURL)
        }
    }
    
    @IBAction func uploadBlocksV2Program(_ sender: Any) {
        let program = DefaultProgram(programName: NSLocalizedString("Mini_Blocks_Program", comment: ""), url: "https://go.calliope.cc/downloads/BlocksV2.hex")
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }

    @IBAction func uploadBlocksV3Program(_ sender: Any) {
        let program = DefaultProgram(programName: NSLocalizedString("Mini_Blocks_Program", comment: ""), url: "https://go.calliope.cc/downloads/BlocksV3.hex")
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }
}
