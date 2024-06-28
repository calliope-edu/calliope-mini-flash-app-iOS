//
//  ProjectCollectionViewCell.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import UIKit

protocol ProjectCellDelegate {
    func deleteProject(of cell: ProjectCollectionViewCell, project: Project)
}

class ProjectCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var projectName: UILabel!
    
    public var delegate: ProjectCellDelegate!
    
    public var project: Project! {
        didSet {
            projectName.text = project.name
        }
    }
    
    @IBAction func deleteProject(_ sender: Any) {
        delegate.deleteProject(of: self, project: project)
    }
}

