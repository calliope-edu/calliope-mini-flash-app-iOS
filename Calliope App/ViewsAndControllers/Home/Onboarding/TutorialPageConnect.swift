//
//  TutorialConnectViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class TutorialPageConnect: TutorialPageViewController, AnimatingTutorialViewController {
    
    let unconnectedText = NSLocalizedString("Push the button and follow the instructions for connecting to your Calliope", comment: "")
    let succeededText = NSLocalizedString("You are connected to your Calliope, well done!", comment: "")
        
    @IBOutlet weak var instructionLabel: UILabel!
    
    var hasConnected: Bool {
        return MatrixConnectionViewController.instance.usageReadyCalliope != nil
    }
    
    @IBOutlet weak var collectionView: UICollectionView?
    
    var cellIdentifier = "cell"
    
    var animationStep = 0
    
    var animationSpeed = 0.3
    
    var cellSize = CGSize(width: 100, height: 100) //will adjust on view layout
    
    @IBOutlet weak var continueButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var continueButton: UIButton!
    
    var readyCalliopeObservation: Any? = nil
    var disconnectedCalliopeObservation: Any? = nil
    
    var cellConfigurations: [(String?, UIImage?, [UIImage]?, [UIImage]?)]  =
        [(nil, nil, [#imageLiteral(resourceName: "ble_00")], nil),
         (nil, nil, [#imageLiteral(resourceName: "ble_01")], nil),
         (nil, nil, [#imageLiteral(resourceName: "ble_02_00"), #imageLiteral(resourceName: "ble_02_01"), #imageLiteral(resourceName: "ble_02_02"), #imageLiteral(resourceName: "ble_02_03"), #imageLiteral(resourceName: "ble_02_04"), #imageLiteral(resourceName: "ble_02_05")], nil),
         (nil, nil, [#imageLiteral(resourceName: "blr_03")], nil)]
    
    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let sizeOfView = self.collectionView?.frame.size ?? CGSize(width: 100, height: 100)
        let cellSidelength = min(min(sizeOfView.width, sizeOfView.height), 720) / 2.0 - 20
        cellSize = CGSize(width: cellSidelength, height: cellSidelength)
    }
    
    fileprivate func updateConnectionState() {
        self.setText()
        self.checkHasConnected()
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkHasConnected()
        readyCalliopeObservation = NotificationCenter.default
            .addObserver(forName: CalliopeBLEDevice.usageReadyNotificationName, object: nil, queue: OperationQueue.main,
                         using: { _ in self.updateConnectionState() })
        disconnectedCalliopeObservation = NotificationCenter.default
            .addObserver(forName: CalliopeBLEDevice.disconnectedNotificationName, object: nil, queue: OperationQueue.main,
                         using: { _ in self.updateConnectionState() })
        updateConnectionState()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delay(time: 1.0) {
            MatrixConnectionViewController.instance.animateBounce()
            self.animate()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(false)
        NotificationCenter.default.removeObserver(readyCalliopeObservation!)
        NotificationCenter.default.removeObserver(disconnectedCalliopeObservation!)
    }
    
    @IBAction override func nextPage(_ sender: Any) {
        setText()
        if hasConnected {
            delay(time: 0.8) {
                self.delegate?.proceed(from: self, completed: true)
            }
        } else {
            MatrixConnectionViewController.instance.animateBounce()
        }
    }
    
    override func attemptProceed() -> (Bool, Bool) {
        if hasConnected {
            return (true, true)
        } else {
            MatrixConnectionViewController.instance.animateBounce()
            return (false, false)
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
    
    private func checkHasConnected() {
        if hasConnected {
            continueButtonHeightConstraint.constant = 40
            continueButton.isHidden = false
        } else {
            continueButtonHeightConstraint.constant = 0
            continueButton.isHidden = true
        }
    }
    
    //MARK: proxy functions to settle UICollectionViewDataSource Objective C Interop problem
    
    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return proxyCollectionView(collectionView, numberOfItemsInSection: section)
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return proxyCollectionView(collectionView, cellForItemAt: indexPath)
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return proxyCollectionView(collectionView, layout: collectionViewLayout, sizeForItemAt: indexPath)
    }
}
