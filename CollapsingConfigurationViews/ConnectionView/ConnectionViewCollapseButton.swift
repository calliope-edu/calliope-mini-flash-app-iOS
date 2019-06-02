//
//  CollapseButton.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 23.12.18.
//

import UIKit

class ConnectionViewCollapseButton: UIButton, CollapseButtonProtocol {

	public enum ConnectionState {
		case disconnected
		case connecting
		case connected
	}

	public var connectionState: ConnectionState = .disconnected {
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
			case .disconnected:
				self.setImages(smooth, UIImage(named: "liveviewconnect/mini_button_circle_red"), UIImage(named: "liveviewconnect/mini_mini"), for: .normal)
			case .connecting:
				self.setImages(smooth, UIImage(named: "liveviewconnect/mini_button_circle_red"), UIImage(named: "liveviewconnect/connect"), for: .normal)
			case .connected:
				self.setImages(smooth, UIImage(named: "liveviewconnect/mini_button_circle_green"), UIImage(named: "liveviewconnect/mini_mini"), for: .normal)
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
}
