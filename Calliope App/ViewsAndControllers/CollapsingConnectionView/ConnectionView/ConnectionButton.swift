//
//  ConnectionButton.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 22.12.18.
//

import UIKit

class ConnectionButton: UIButton {

	public enum ConnectionState {
		case initialized
		case waitingForBluetooth
		case searching
		case notFoundRetry
		case readyToConnect
		case connecting
		case testingMode
		case readyToPlay
		case wrongProgram
	}

	public var connectionState: ConnectionState = .initialized {
		didSet {
			UIView.transition(with: self, duration: 0.5, options: .transitionCrossDissolve, animations: {
                switch self.connectionState {
                case .initialized:
                    self.isEnabled = true
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_refresh"), for: .normal)
                case .waitingForBluetooth:
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/bluetooth_disabled"), for: .normal)
                case .searching:
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_mini"), for: .normal)
                case .notFoundRetry:
                    self.isEnabled = true
                    self.setBackgroundImage(UIImage(named: "liveviewconnect/mini_button_red"), for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_refresh"), for: .normal)
                case .readyToConnect:
                    self.isEnabled = true
                    self.setBackgroundImage(UIImage(named: "liveviewconnect/mini_button_green"), for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_pfeil"), for: .normal)
                case .connecting:
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/connect"), for: .normal)
                case .testingMode:
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_test_mode"), for: .normal)
                //TODO: number animation
                case .readyToPlay:
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_figur"), for: .normal)
                case .wrongProgram:
                    self.isEnabled = false
                    self.setBackgroundImage(UIImage(named: "liveviewconnect/mini_button_red"), for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_wrong_mode"), for: .normal)
                }
            }, completion: nil)
        }
    }

    func animateBounce() {
        let originalTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0);
        UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseOut, animations: {
            self.transform = originalTransform.scaledBy(x: 1.5, y: 1.5)
            self.superview?.layoutIfNeeded()
        }) { _ in
            UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: .curveEaseIn, animations: {
                self.transform = originalTransform
                self.superview?.layoutIfNeeded()
            }, completion: nil)
        }
    }
}
