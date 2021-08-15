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
                    self.imageView?.stopAnimating()
                    self.imageView?.animationImages = nil
                    self.isEnabled = true
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_refresh"), for: .normal)
                case .waitingForBluetooth:
                    self.imageView?.stopAnimating()
                    self.imageView?.animationImages = nil
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/bluetooth_disabled"), for: .normal)
                case .searching:
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    let images = [#imageLiteral(resourceName: "AnimProgress/0001"),#imageLiteral(resourceName: "AnimProgress/0002"),#imageLiteral(resourceName: "AnimProgress/0003"),#imageLiteral(resourceName: "AnimProgress/0004"),#imageLiteral(resourceName: "AnimProgress/0005"),#imageLiteral(resourceName: "AnimProgress/0006"),#imageLiteral(resourceName: "AnimProgress/0007"),#imageLiteral(resourceName: "AnimProgress/0008"),#imageLiteral(resourceName: "AnimProgress/0009"),#imageLiteral(resourceName: "AnimProgress/0010"),#imageLiteral(resourceName: "AnimProgress/0011"),#imageLiteral(resourceName: "AnimProgress/0012"),#imageLiteral(resourceName: "AnimProgress/0013"),#imageLiteral(resourceName: "AnimProgress/0014"),#imageLiteral(resourceName: "AnimProgress/0015"),#imageLiteral(resourceName: "AnimProgress/0016"),#imageLiteral(resourceName: "AnimProgress/0017"),#imageLiteral(resourceName: "AnimProgress/0018"),#imageLiteral(resourceName: "AnimProgress/0019"),#imageLiteral(resourceName: "AnimProgress/0020")]
                    self.imageView?.animationImages = images
                    self.imageView?.animationDuration = 0.1 * Double(images.count)
                    self.imageView?.startAnimating()
                case .notFoundRetry:
                    self.imageView?.stopAnimating()
                    self.imageView?.animationImages = nil
                    self.isEnabled = true
                    self.setBackgroundImage(UIImage(named: "liveviewconnect/mini_button_red"), for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/connect_refresh"), for: .normal)
                case .readyToConnect:
                    self.imageView?.stopAnimating()
                    self.imageView?.animationImages = nil
                    self.isEnabled = true
                    self.setBackgroundImage(UIImage(named: "liveviewconnect/mini_button_green"), for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/connect_0001"), for: .normal)
                case .connecting:
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    let images = [#imageLiteral(resourceName: "liveviewconnect/connect_0001"),#imageLiteral(resourceName: "liveviewconnect/connect_0002"),#imageLiteral(resourceName: "liveviewconnect/connect_0003"),#imageLiteral(resourceName: "liveviewconnect/connect_0004"),#imageLiteral(resourceName: "liveviewconnect/connect_0005"),#imageLiteral(resourceName: "liveviewconnect/connect_0006"),#imageLiteral(resourceName: "liveviewconnect/connect_0007"),#imageLiteral(resourceName: "liveviewconnect/connect_0008"),#imageLiteral(resourceName: "liveviewconnect/connect_0009"),#imageLiteral(resourceName: "liveviewconnect/connect_0010"),#imageLiteral(resourceName: "liveviewconnect/connect_0009"),#imageLiteral(resourceName: "liveviewconnect/connect_0008"),#imageLiteral(resourceName: "liveviewconnect/connect_0007"),#imageLiteral(resourceName: "liveviewconnect/connect_0006"),#imageLiteral(resourceName: "liveviewconnect/connect_0005"),#imageLiteral(resourceName: "liveviewconnect/connect_0004"),#imageLiteral(resourceName: "liveviewconnect/connect_0003"),#imageLiteral(resourceName: "liveviewconnect/connect_0002"),#imageLiteral(resourceName: "liveviewconnect/connect_0001")]
                    self.imageView?.animationImages = images
                    self.imageView?.animationDuration = 0.1 * Double(images.count)
                    self.imageView?.startAnimating()
                case .testingMode:
                    break
                    //self.isEnabled = false
                    //self.setBackgroundImage(nil, for: .normal)
                    //let images = [#imageLiteral(resourceName: "liveviewconnect/connect_0001"),#imageLiteral(resourceName: "liveviewconnect/connect_0002"),#imageLiteral(resourceName: "liveviewconnect/connect_0003"),#imageLiteral(resourceName: "liveviewconnect/connect_0004"),#imageLiteral(resourceName: "liveviewconnect/connect_0005"),#imageLiteral(resourceName: "liveviewconnect/connect_0006"),#imageLiteral(resourceName: "liveviewconnect/connect_0007"),#imageLiteral(resourceName: "liveviewconnect/connect_0008"),#imageLiteral(resourceName: "liveviewconnect/connect_0009"),#imageLiteral(resourceName: "liveviewconnect/connect_0010"),#imageLiteral(resourceName: "liveviewconnect/connect_0009"),#imageLiteral(resourceName: "liveviewconnect/connect_0008"),#imageLiteral(resourceName: "liveviewconnect/connect_0007"),#imageLiteral(resourceName: "liveviewconnect/connect_0006"),#imageLiteral(resourceName: "liveviewconnect/connect_0005"),#imageLiteral(resourceName: "liveviewconnect/connect_0004"),#imageLiteral(resourceName: "liveviewconnect/connect_0003"),#imageLiteral(resourceName: "liveviewconnect/connect_0002"),#imageLiteral(resourceName: "liveviewconnect/connect_0001")]
                    //self.imageView?.animationImages = images
                    //self.imageView?.animationDuration = 0.1 * Double(images.count)
                    //self.imageView?.startAnimating()
                case .readyToPlay:
                    self.imageView?.stopAnimating()
                    self.imageView?.animationImages = nil
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/mini_figur"), for: .normal)
                case .wrongProgram:
                    self.imageView?.stopAnimating()
                    self.imageView?.animationImages = nil
                    self.isEnabled = false
                    self.setBackgroundImage(nil, for: .normal)
                    self.setImage(UIImage(named: "liveviewconnect/connect_failed"), for: .normal)
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
