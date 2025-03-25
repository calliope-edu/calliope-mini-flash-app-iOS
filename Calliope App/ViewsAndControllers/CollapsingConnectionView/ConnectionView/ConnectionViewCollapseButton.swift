//
//  CollapseButton.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 23.12.18.
//

import UIKit

class ConnectionViewCollapseButton: UIButton, CollapseButtonProtocol {

	public enum ConnectionState {
		case disabled
		case disconnected
		case connecting
		case connected
		case transmitting
	}

	public var connectionState: ConnectionState = .disabled {
		didSet {
			if oldValue != connectionState {
				determineAppearance(smooth: true)
			}
		}
	}

	public var expansionState: ExpansionState = .open {
		didSet {
			if oldValue != expansionState {
				determineAppearance(smooth: false)
			}
		}
	}

	private func determineAppearance(smooth: Bool) {
		if self.expansionState == .open {
			self.setImages(smooth, nil, UIImage(named: "liveviewconnect/mini_close"), for: .normal)
		} else {
			switch self.connectionState {
			case .disabled:
				self.setImages(smooth, nil, nil, for: .normal)
			case .disconnected:
				self.setImages(smooth, UIImage(named: "liveviewconnect/mini_button_circle_red"), UIImage(named: "liveviewconnect/mini_mini"), for: .normal)
			case .connecting:
				self.setImages(smooth, UIImage(named: "liveviewconnect/mini_button_circle_red"), UIImage(named: "liveviewconnect/connect"), for: .normal)
			case .connected:
				self.setImages(smooth, UIImage(named: "liveviewconnect/mini_button_circle_green"), UIImage(named: "liveviewconnect/mini_mini"), for: .normal)
			case .transmitting:
				self.setImages(smooth, UIImage(named: "liveviewconnect/mini_button_circle_green"), UIImage(named: "liveviewconnect/connect"), for: .normal) // TODO SKO: Update as soon as we have the corresponding assets
			}
		}
	}

	private func setImages(_ smooth: Bool, _ backgroundImage: UIImage?, _ foregroundImage: UIImage?, for state: UIControl.State) {

		let animations = {
			self.setBackgroundImage(backgroundImage, for: state)
			self.setImage(foregroundImage, for: state)
		}

		if smooth {
			UIView.transition(with: self, duration: 0.2, options: [.transitionCrossDissolve, .allowAnimatedContent, .curveLinear], animations: animations, completion: nil)
		} else {
			animations()
		}
	}

	func animateBounce() {
		let originalTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
		UIView.animate(
			withDuration: 0.25, delay: 0.0, options: .curveEaseOut,
			animations: {
				self.transform = originalTransform.scaledBy(x: 1.5, y: 1.5)
				self.superview?.layoutIfNeeded()
			}
		) { _ in
			UIView.animate(
				withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: .curveEaseIn,
				animations: {
					self.transform = originalTransform
					self.superview?.layoutIfNeeded()
				}, completion: nil)
		}
	}
}
