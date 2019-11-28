//
//  ProgramCollectionViewCell.swift
//  Calliope
//
//  Created by Tassilo Karge on 08.06.19.
//

import UIKit

protocol ProgramCellDelegate {
	func share(cell: ProgramCollectionViewCell)
	func renameFailed(_ cell: ProgramCollectionViewCell, to newName: String)
	func programCellSizeDidChange(_ cell: ProgramCollectionViewCell)
	func uploadProgram(of cell: ProgramCollectionViewCell)
	func deleteProgram(of cell: ProgramCollectionViewCell)
}

class ProgramCollectionViewCell: UICollectionViewCell, UITextViewDelegate {
	@IBOutlet weak var image: UIImageView?
	@IBOutlet weak var descriptionText: UITextView? {
		didSet {
			descriptionText?.delegate = self
		}
	}
	@IBOutlet weak var name: UILabel!
    @IBOutlet weak var dateLabel: UILabel?
	@IBOutlet weak var nameEditField: UITextField!
	@IBOutlet weak var buttonContainer: UIView?
	@IBOutlet weak var editButton: UIButton?
	@IBOutlet weak var shareButton: UIButton?

    @IBOutlet weak var containerView: UIView?
    
	@IBOutlet weak var widthConstraint: NSLayoutConstraint!
    
    var simpleCell: Bool {
        return buttonContainer == nil
    }

	public var program: HexFile! {
		didSet {
			name.text = program.name
			nameEditField.text = program.name
            descriptionText?.text = program.dateString
            dateLabel?.text = program.dateString
		}
	}

	public var delegate: ProgramCellDelegate!

	public var editing = false {
		didSet {
			//changed from editing to not editing
			if oldValue && !editing {
				let newDescription = (descriptionText?.text != nil && descriptionText?.text != "") ? descriptionText!.text! : program.dateString
				let newName = nameEditField.text ?? ""
				setProgramName(newName)
				setProgramDescription(newDescription)
			}

            if !editing {
                editButton?.setTitle("Edit", for: .normal)
            } else {
                editButton?.setTitle("Finished", for: .normal)
            }
            
			descriptionText?.isEditable = editing && !simpleCell
            descriptionText?.backgroundColor = editing && !simpleCell ? UIColor.white : nil
			name.isHidden = editing
            nameEditField.isHidden = !editing
            shareButton?.isHidden = editing
		}
	}

	override func awakeFromNib() {
		super.awakeFromNib()

		contentView.translatesAutoresizingMaskIntoConstraints = false

		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView]|", options: [], metrics: nil, views: ["contentView" : self.contentView]))
		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView]|", options: [], metrics: nil, views: ["contentView" : self.contentView]))
	}
    
	override func layoutSubviews() {
		super.layoutSubviews()
		descriptionText?.textContainerInset = UIEdgeInsets.zero
		self.changeTextExclusion()
	}

	private func setProgramName(_ newName: String) {
		program.name = newName
		if program.name != newName {
			//rename was not successful
			delegate.renameFailed(self, to: newName)
		}
	}

	private func setProgramDescription(_ newDescription: String) {
		//TODO: there is no description saved in a hex file yet
	}

	func changeTextExclusion() {
        guard  let descriptionText = descriptionText, let containerView = containerView, let buttonContainer = buttonContainer, let image = image else { return }
		descriptionText.textContainer.exclusionPaths = [
			UIBezierPath(rect: containerView.convert(image.frame.intersection(descriptionText.frame), to: descriptionText)),
			UIBezierPath(rect: containerView.convert(buttonContainer.frame.intersection(descriptionText.frame), to: descriptionText))]
	}
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == Selector(("edit")) || action == Selector(("share")) || action == #selector(delete(_:))
    }

	@IBAction func editButtonClicked(_ sender: Any) {
		editing = !editing
        delegate.programCellSizeDidChange(self)
	}

	@IBAction func shareButtonClicked(_ sender: Any) {
		self.delegate.share(cell: self)
	}

	@IBAction func uploadButtonClicked(_ sender: Any) {
		delegate.uploadProgram(of: self)
	}

	override func delete(_ sender: Any?) {
		delegate.deleteProgram(of: self)
	}
    
    @objc func edit() {
        editing = true
    }
    
    @objc func share() {
        delegate.share(cell: self)
    }

	// MARK: UITextViewDelegate

	func textViewDidChange(_ textView: UITextView) {
		delegate.programCellSizeDidChange(self)
	}

}
