//
//  MainContainerViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 02.06.19.
//

import UIKit

class MainContainerViewController: UIViewController {

	@IBOutlet weak var matrixConnectionView: UIView!
	@IBOutlet weak var tabBarView: UIView!

	weak var connectionViewController: MatrixConnectionViewController!

	override func viewDidLoad() {
        super.viewDidLoad()
		connectionViewController.view.snp.makeConstraints { (make) -> Void in
			make.edges.equalTo(self.matrixConnectionView)
		}
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "embedConnectionView" {
			connectionViewController = (segue.destination as! MatrixConnectionViewController)
		}
    }

}
