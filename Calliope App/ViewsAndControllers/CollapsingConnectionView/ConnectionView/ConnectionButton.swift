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

            //testingMode is only an intermediate state, no animation change.
            guard self.connectionState != .testingMode else {
                return
            }

			switch self.connectionState {
                case .initialized:
                    self.configureButton(background: nil,
                                         foreground: UIImage(named: "liveviewconnect/mini_refresh"),
                                         animationImages: nil,
                                         enabled: true)
                case .waitingForBluetooth:
                    self.configureButton(background: nil,
                                         foreground: UIImage(named: "liveviewconnect/bluetooth_disabled"),
                                         animationImages: nil,
                                         enabled: false)
                case .searching:
                    let images = [#imageLiteral(resourceName: "AnimProgress/0001"),#imageLiteral(resourceName: "AnimProgress/0002"),#imageLiteral(resourceName: "AnimProgress/0003"),#imageLiteral(resourceName: "AnimProgress/0004"),#imageLiteral(resourceName: "AnimProgress/0005"),#imageLiteral(resourceName: "AnimProgress/0006"),#imageLiteral(resourceName: "AnimProgress/0007"),#imageLiteral(resourceName: "AnimProgress/0008"),#imageLiteral(resourceName: "AnimProgress/0009"),#imageLiteral(resourceName: "AnimProgress/0010"),#imageLiteral(resourceName: "AnimProgress/0011"),#imageLiteral(resourceName: "AnimProgress/0012"),#imageLiteral(resourceName: "AnimProgress/0013"),#imageLiteral(resourceName: "AnimProgress/0014"),#imageLiteral(resourceName: "AnimProgress/0015"),#imageLiteral(resourceName: "AnimProgress/0016"),#imageLiteral(resourceName: "AnimProgress/0017"),#imageLiteral(resourceName: "AnimProgress/0018"),#imageLiteral(resourceName: "AnimProgress/0019"),#imageLiteral(resourceName: "AnimProgress/0020")]
                    self.configureButton(background: nil,
                                         foreground: nil,
                                         animationImages: images,
                                         animationDuration: 0.1 * Double(images.count),
                                         enabled: false)
                case .notFoundRetry:
                    self.configureButton(background: UIImage(named: "liveviewconnect/mini_button_red"),
                                         foreground: UIImage(named: "liveviewconnect/connect_refresh"),
                                         animationImages: nil,
                                         enabled: true)
                case .readyToConnect:
                    self.configureButton(background: UIImage(named: "liveviewconnect/mini_button_green"),
                                         foreground: UIImage(named: "liveviewconnect/connect_0001"),
                                         animationImages: nil,
                                         enabled: true)
                case .connecting:
                    let images = [#imageLiteral(resourceName: "liveviewconnect/connect_0001"),#imageLiteral(resourceName: "liveviewconnect/connect_0002"),#imageLiteral(resourceName: "liveviewconnect/connect_0003"),#imageLiteral(resourceName: "liveviewconnect/connect_0004"),#imageLiteral(resourceName: "liveviewconnect/connect_0005"),#imageLiteral(resourceName: "liveviewconnect/connect_0006"),#imageLiteral(resourceName: "liveviewconnect/connect_0007"),#imageLiteral(resourceName: "liveviewconnect/connect_0008"),#imageLiteral(resourceName: "liveviewconnect/connect_0009"),#imageLiteral(resourceName: "liveviewconnect/connect_0010"),#imageLiteral(resourceName: "liveviewconnect/connect_0009"),#imageLiteral(resourceName: "liveviewconnect/connect_0008"),#imageLiteral(resourceName: "liveviewconnect/connect_0007"),#imageLiteral(resourceName: "liveviewconnect/connect_0006"),#imageLiteral(resourceName: "liveviewconnect/connect_0005"),#imageLiteral(resourceName: "liveviewconnect/connect_0004"),#imageLiteral(resourceName: "liveviewconnect/connect_0003"),#imageLiteral(resourceName: "liveviewconnect/connect_0002"),#imageLiteral(resourceName: "liveviewconnect/connect_0001")]
                    self.configureButton(background: nil,
                                         foreground: nil,
                                         animationImages: images,
                                         animationDuration: 0.05 * Double(images.count),
                                         enabled: false)
                case .testingMode:
                    break //already skipped this part at function start, will not happen
                case .readyToPlay:
                    self.configureButton(background: nil,
                                         foreground: UIImage(named: "liveviewconnect/mini_figur"),
                                         animationImages: nil,
                                         enabled: false)
                case .wrongProgram:
                    self.configureButton(background: nil,
                                         foreground: UIImage(named: "liveviewconnect/connect_failed"),
                                         animationImages: nil,
                                         enabled: false)
                }
        }
    }

    func configureButton(background: UIImage?, foreground: UIImage?,
                         animationImages: [UIImage]?, animationDuration: Double = 1.0,
                         enabled: Bool) {

        UIView.transition(with: self,
                          duration: 0.5,
                          options: [.transitionCrossDissolve, .beginFromCurrentState],
                          animations: {

            if animationImages == nil {
                self.imageView?.stopAnimating()
                self.imageView?.animationImages = nil
            }

            self.isEnabled = enabled
            self.setBackgroundImage(background, for: .normal)

            if animationImages == nil {
                self.setImage(foreground, for: .normal)
            }

            if let animationImages = animationImages {
                self.imageView?.animationImages = animationImages
                self.imageView?.animationDuration = animationDuration
                self.imageView?.startAnimating()
            }
        }, completion: nil)
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
