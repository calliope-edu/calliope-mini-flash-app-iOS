//
//  ProjectCollectionViewCell.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import UIKit

protocol ProjectCellDelegate {
    func share(cell: ProjectCollectionViewCell)
    func renameFailed(_ cell: ProjectCollectionViewCell, to newName: String)
    func uploadProgram(of cell: ProjectCollectionViewCell)
    func deleteProgram(of cell: ProjectCollectionViewCell)
}

class ProjectCollectionViewCell: AutoHeightCollectionViewCell {
    @IBOutlet weak var image: UIImageView?
    @IBOutlet weak var descriptionText: UITextView?
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

    public var project: Project! {
        didSet {
            name.text = project.name
            nameEditField.text = project.name
        }
    }

    public var delegate: ProjectCellDelegate!

    public var editing = false {
        didSet {
            //changed from editing to not editing
            if oldValue && !editing {
                let newDescription = (descriptionText?.text != nil && descriptionText?.text != "") ? descriptionText!.text! : project.name
                let newName = nameEditField.text ?? ""
                setProgramName(newName)
                setProgramDescription(newDescription)
            }

            if !editing {
                editButton?.setTitle(NSLocalizedString("Edit", comment: ""), for: .normal)
            } else {
                editButton?.setTitle(NSLocalizedString("Finished", comment: ""), for: .normal)
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
        project.name = newName
        if project.name != newName {
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
        return action == #selector(self.edit) || action == #selector(self.share) || action == #selector(delete(_:))
    }

    @IBAction func editButtonClicked(_ sender: Any) {
        editing = !editing
    }

    @IBAction func shareButtonClicked(_ sender: Any) {
        self.delegate.share(cell: self)
    }

    @IBAction func uploadButtonClicked(_ sender: Any) {
        delegate.uploadProgram(of: self)
    }

    override func delete(_ sender: Any?) {
        self.delete()
    }

    @objc func delete() {
        delegate.deleteProgram(of: self)
    }
    
    @objc func edit() {
        editing = true
    }
    
    @objc func share() {
        delegate.share(cell: self)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

}

