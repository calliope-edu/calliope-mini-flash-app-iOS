//
//  ProjectController.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import UIKit
import DGCharts

class ProjectViewController: UIViewController, ChartViewDelegate {
    var project: Project?
    var projectId: Int?
    
    @IBOutlet weak var chartsContainerView: UIView?
    
    @objc var chartCollectionViewController: ChartCollectionViewController?
    var chartHeightConstraint: NSLayoutConstraint?
    var chartsKvo: Any?
    
    init?(coder: NSCoder, project: Project) {
        self.project = project
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        chartsContainerView?.translatesAutoresizingMaskIntoConstraints = false
        chartHeightConstraint = chartsContainerView?.heightAnchor.constraint(equalToConstant: 10)
        chartHeightConstraint?.isActive = true
        
        chartCollectionViewController?.project = project
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        chartsKvo = observe(\.chartCollectionViewController?.collectionView.contentSize) { (containerVC, _) in
            containerVC.chartHeightConstraint!.constant = containerVC.chartCollectionViewController!.collectionView.contentSize.height
            containerVC.chartCollectionViewController?.collectionView.layoutIfNeeded()
        }
        
        chartsContainerView?.backgroundColor = .red
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        chartsKvo = nil
    }
    
    @IBSegueAction func initializeCharts(_ coder: NSCoder) -> ChartCollectionViewController? {
        chartCollectionViewController = ChartCollectionViewController(coder: coder)
        self.reloadInputViews()
        return chartCollectionViewController
    }
    
    @IBAction func recordNewSensor() {
        chartCollectionViewController?.addChart()
    }
}
