//
//  ProjectController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit

class ProjectController: UIViewController {
    
    
    @IBOutlet var mainView: UIView!
    var project: Project?
    var projectId: Int?
    
    init?(coder: NSCoder, project: Project) {
        self.project = project
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        print("View did Load LEL")
        print(project?.name)
        super.viewDidLoad()
    }
}
