//
//  CollapsingViewController.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 04.05.19.
//

import UIKit

protocol CollapsingViewControllerProtocol: AnyObject {

	var view: UIView! { get }

	var zoomView: UIView! { get }
	var collapseButtonView: (CollapseButtonProtocol & UIView)! { get }
	var collapseHeightConstraint: NSLayoutConstraint! { get }
	var collapseWidthConstraint: NSLayoutConstraint! { get }

	var collapsedWidth: CGFloat { get }
	var collapsedHeight: CGFloat { get }
	var expandedWidth: CGFloat { get }
	var expandedHeight: CGFloat { get }

	func animationCompletions(expand: Bool)
}

extension CollapsingViewControllerProtocol {
	func toggleOpen() {
		if collapseButtonView.expansionState == .open {
			//button state open --> collapse!
			animate(expand: false)
		} else {
			//button state closed --> open!
			animate(expand: true)
		}
	}

    public func animate(expand: Bool, animate: Bool = true) {

		view.layer.masksToBounds = false
		view.layer.shadowColor = UIColor.darkGray.cgColor
		view.layer.shadowOpacity = 0.5
		view.layer.shadowOffset = CGSize(width: 0, height: 0)

		//do not animate anything if no change will happen
		guard expand && collapseButtonView.expansionState == .closed || collapseButtonView.expansionState == .open else { return }

		let animations: () -> ()
		let completion: () -> ()

		if expand {
			self.zoomView.isHidden = false
			animations = {
				self.view.layer.shadowRadius = 10
				self.collapseHeightConstraint.constant = self.expandedHeight
				self.collapseWidthConstraint.constant = self.expandedWidth
				self.collapseButtonView.alpha = 0.0
			}
			completion = {
				self.collapseButtonView.expansionState = .open
				self.collapseButtonView.alpha = 1.0
			}
		} else {
			self.collapseButtonView.alpha = 0.0
			animations = {
				self.view.layer.shadowRadius = 5
				self.collapseHeightConstraint.constant = self.collapsedHeight
				self.collapseWidthConstraint.constant = self.collapsedWidth
				self.collapseButtonView.expansionState = .closed
				self.collapseButtonView.alpha = 1.0
				self.zoomView.alpha = 0.0
			}
			completion = {
				self.collapseButtonView.alpha = 1.0
				self.zoomView.alpha = 1.0
				self.zoomView.isHidden = true
			}
		}

        if !animate {
            animations()
            completion()
            if let superview = self.view.superview?.superview {
                //if used in storyboard embedded view
                superview.layoutIfNeeded()
            } else {
                //if used plain
                self.view.superview?.layoutIfNeeded()
            }
        } else {
            UIView.animate(withDuration: TimeInterval(0.3), animations: {
                animations()
                if let superview = self.view.superview?.superview {
                    //if used in storyboard embedded view
                    superview.layoutIfNeeded()
                } else {
                    //if used plain
                    self.view.superview?.layoutIfNeeded()
                }
            }) { _ in
                completion()
                self.animationCompletions(expand: expand)
            }
        }
	}
}
